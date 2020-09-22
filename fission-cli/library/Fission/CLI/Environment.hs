-- | Reading and writing local user config values
module Fission.CLI.Environment
  ( init
  , get
  , couldNotRead
  , getOrRetrievePeers

  -- * Reexport

  , module Fission.CLI.Environment.Class
  , module Fission.CLI.Environment.Types
  ) where

import           Data.List.NonEmpty               as NonEmpty hiding (init,
                                                               (<|))
import qualified Data.Yaml                        as YAML
import           RIO.Directory
import           RIO.FilePath

import           Servant.Client

import qualified Network.IPFS.Types               as IPFS
import qualified System.Console.ANSI              as ANSI
import qualified System.FilePath.Glob             as Glob

import           Fission.Prelude

import           Fission.Web.Client
import           Fission.Web.Client.Peers         as Peers

import qualified Fission.CLI.Display.Error        as CLI.Error

import           Fission.CLI.Environment.Class
import           Fission.CLI.Environment.Types

import           Fission.CLI.Environment.Override hiding (get)
import qualified Fission.CLI.Environment.Override as Override

import qualified Fission.Internal.UTF8            as UTF8

-- | Initialize the Environment file
init ::
  ( MonadIO        m
  , MonadLogger    m
  , MonadWebClient m

  , MonadCleanup   m
  , m `Raises` ClientError
  , Show (OpenUnion (Errors m))
  )
  => m ()
init = do
  logDebug @Text "Initializing config file"

  attempt Peers.getPeers >>= \case
    Left err ->
      CLI.Error.put err "Peer retrieval failed"

    Right nonEmptyPeers -> do
      let
        env = mempty
          { peers        = NonEmpty.toList nonEmptyPeers
          , maybeIgnored = Just ignoreDefault
          }

      path <- Override.globalConfig
      liftIO $ path `Override.writeFile` env

-- | Gets hierarchical environment by recursing through file system
get ::
  ( MonadIO    m
  , MonadRaise m
  , m `Raises` YAML.ParseException
  )
  => m Environment
get = do
  local  <- decodeFile =<< Override.localConfig
  global <- decodeFile =<< Override.globalConfig
  return $ Override.toFull (local <> global)

-- | Create a could not read message for the terminal
couldNotRead :: MonadIO m => m ()
couldNotRead = do
  liftIO $ ANSI.setSGR [ANSI.SetColor ANSI.Foreground ANSI.Vivid ANSI.Red]
  UTF8.putText "🚫 Unable to read credentials. Try logging in with "

  liftIO $ ANSI.setSGR [ANSI.SetColor ANSI.Foreground ANSI.Vivid ANSI.Blue]
  UTF8.putText "fission login\n"

  liftIO $ ANSI.setSGR [ANSI.Reset]

-- | Retrieves a Fission Peer from local config
--   If not found we retrive from the network and store
getOrRetrievePeers ::
  ( MonadIO        m
  , MonadLogger    m
  , MonadWebClient m

  , MonadCleanup   m
  , m `Raises` ClientError
  , m `Raises` YAML.ParseException
  , Show (OpenUnion (Errors m))
  )
  => Environment
  -> m [IPFS.Peer]
getOrRetrievePeers Environment {peers = []} =
  attempt Peers.getPeers >>= \case
    Left err -> do
      logError $ displayShow err
      logDebug @Text "Unable to retrieve peers from the network"
      return []

    Right nonEmptyPeers -> do
      path <- Override.globalConfig
      let peers = NonEmpty.toList nonEmptyPeers
      logDebug $ "Retrieved Peers from API, and writing to ~/.fission.yaml: " <> textShow peers
      Override.writeMerge path $ mempty { peers }
      return peers

getOrRetrievePeers Environment {peers} = do
  logDebug $ "Retrieved Peers from .fission.yaml: " <> textShow peers
  return peers

ignoreDefault :: IPFS.Ignored
ignoreDefault =
  [ Glob.compile ".fission.yaml"
  , Glob.compile ".env"
  , Glob.compile ".DS_Store"
  ]
