-- | File sync, IPFS-style
module Fission.CLI.Handler.App.Publish (publish) where

import qualified Data.Yaml                                 as YAML

import qualified Crypto.PubKey.Ed25519                     as Ed25519
import           System.FSNotify                           as FS

import           RIO.Directory
import           Web.Browser

import           Network.HTTP.Types.Status
import qualified Network.IPFS.Process.Error                as IPFS.Process

import           Network.IPFS
import           Network.IPFS.CID.Types

import           Fission.Prelude

import qualified Fission.Web.Client.App                    as App

import qualified Fission.Internal.UTF8                     as UTF8

import qualified Fission.Time                              as Time
import           Fission.URL

import           Fission.Authorization.ServerDID
import           Fission.Error.NotFound.Types

import           Fission.Web.Auth.Token.JWT                as JWT
import           Fission.Web.Auth.Token.Types

import           Fission.Web.Client                        as Client
import           Fission.Web.Client.Error

import qualified Fission.CLI.Display.Error                 as CLI.Error
import qualified Fission.CLI.Display.Success               as CLI.Success

import qualified Fission.CLI.IPFS.Add                      as CLI.IPFS.Add
import           Fission.CLI.IPFS.Daemon                   as IPFS.Daemon

import           Fission.CLI.App.Environment               as App
import           Fission.CLI.Parser.Open.Types
import           Fission.CLI.Parser.Watch.Types
import           Fission.CLI.Remote

import           Fission.CLI.Environment                   (MonadEnvironment)
import           Fission.CLI.WebNative.Mutation.Auth.Store as UCAN

-- | Sync the current working directory to the server over IPFS
publish ::
  ( MonadIO          m
  , MonadCleanup     m
  , MonadLogger      m
  , MonadLocalIPFS   m
  , MonadIPFSDaemon  m
  , UCAN.MonadStore  m
  , MonadEnvironment m
  , MonadRemote      m
  , MonadWebClient   m
  , MonadTime        m
  , MonadWebAuth     m Token
  , MonadWebAuth     m Ed25519.SecretKey
  , ServerDID        m
  , m `Raises` YAML.ParseException
  , m `Raises` ClientError
  , m `Raises` IPFS.Process.Error
  , m `Raises` NotFound FilePath
  , Show (OpenUnion (Errors m))
  , CheckErrors m
  )
  => OpenFlag
  -> WatchFlag
  -> (m () -> IO ())
  -> URL
  -> FilePath
  -> Bool
  -> Bool
  -> m ()
publish
  (OpenFlag open)
  (WatchFlag watching)
  runner
  appURL
  appPath
  _updateDNS -- TODO updateDNS
  updateData
    = do
  logDebug @Text "📱 App publish"
  attempt (App.readFrom appPath) >>= \case
    Left err -> do
      CLI.Error.put err "App not set up. Please double check your path, or run `fission app register`"
      raise err

    Right App.Env {buildDir} -> do
      absBuildPath <- liftIO $ makeAbsolute buildDir
      logDebug $ "📱 Starting single IPFS add locally of " <> displayShow absBuildPath
      logUser @Text "🛫 App publish local preflight"

      CLI.IPFS.Add.dir (UTF8.wrapIn "\"" absBuildPath) >>= \case
        Left err -> do
          CLI.Error.put' err
          raise err

        Right cid@(CID hash) -> do
          logDebug $ "📱 Directory CID is " <> hash
          _     <- IPFS.Daemon.runDaemon
          proof <- getRootUserProof
          req   <- App.update appURL cid (Just updateData) <$> Client.attachAuth proof

          logUser @Text "✈️  Pushing to remote"
          retryOnStatus [status502] 100 req >>= \case
            Left err -> do
              CLI.Error.put err "Server unable to sync data"
              raise err

            Right _ -> do
              ipfsGateway <- getIpfsGateway

              when open  do
                liftIO . void . openBrowser $ ipfsGateway <> "/" <> show appURL

              when watching do
                liftIO $ FS.withManager \watchMgr -> do
                  now <- getCurrentTime
                  (hashCache, timeCache) <- atomically do
                    hashCache <- newTVar hash
                    timeCache <- newTVar now
                    return (hashCache, timeCache)

                  void $ handleTreeChanges runner proof appURL updateData timeCache hashCache watchMgr absBuildPath
                  liftIO . forever $ threadDelay 1_000_000 -- Sleep main thread

              success appURL

handleTreeChanges ::
  ( MonadIO        m
  , MonadLogger    m
  , MonadTime      m
  , MonadLocalIPFS m
  , MonadWebClient m
  , MonadWebAuth   m Token
  , MonadWebAuth   m Ed25519.SecretKey
  , ServerDID      m
  )
  => (m () -> IO ())
  -> JWT.Proof
  -> URL
  -> Bool
  -> TVar UTCTime
  -> TVar Text
  -> WatchManager
  -> FilePath -- ^ Build dir
  -> IO StopListening
handleTreeChanges runner userProof appURL copyFilesFlag timeCache hashCache watchMgr absDir =
  FS.watchTree watchMgr absDir (\_ -> True) \_ ->
    runner do
      now <- getCurrentTime

      update <- atomically do
        oldTime <- readTVar timeCache
        if diffUTCTime now oldTime > Time.doherty
          then do
            writeTVar timeCache now
            return True

          else
            return False

      when update do
        CLI.IPFS.Add.dir absDir >>= \case
          Left err ->
            CLI.Error.put' err

          Right cid@(CID newHash) -> do
            maybeOldHash <- atomically do
              oldHash <- readTVar hashCache
              if oldHash == newHash
                then
                  return Nothing

                else do
                  writeTVar hashCache newHash
                  return $ Just oldHash

            case maybeOldHash of
              Nothing ->
                logDebug @Text "CID did not change, noop"

              Just oldHash -> do
                logDebug $ "CID: " <> display oldHash <> " -> " <> display newHash
                UTF8.putNewline
                req <- App.update appURL cid (Just copyFilesFlag) <$> attachAuth userProof

                retryOnStatus [status502] 100 req >>= \case
                  Left err -> CLI.Error.put err "Server unable to sync data"
                  Right _  -> success appURL

success :: MonadIO m => URL -> m ()
success appURL = do
  CLI.Success.live
  CLI.Success.dnsUpdated appURL
