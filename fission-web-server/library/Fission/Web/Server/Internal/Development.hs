-- | Development helpers, primarily for REPL
module Fission.Web.Server.Internal.Development
  ( run
  , runOne
  , mkConfig
  , mkConfig'
  , connectionInfo
  ) where

import           RIO.NonEmpty                              (nonEmpty)
import qualified RIO.Partial                               as Partial

import           Data.Pool
import           Database.Persist.Sql                      (SqlBackend)

import           Servant.Client

import qualified Network.HostName                          as Network

import qualified Network.HTTP.Client                       as HTTP
import qualified Network.HTTP.Client.TLS                   as HTTP

import qualified Network.IPFS.Types                        as IPFS

import           Fission.Prelude

import           Fission.Internal.Fixture.Key.Ed25519      as Fixture.Ed25519

import           Fission.URL.Types
import           Fission.User.DID.Types

import           Fission.Web.API.Remote

import           Fission.Web.Server
import qualified Fission.Web.Server.AWS.Types              as AWS
import qualified Fission.Web.Server.Email.SendInBlue.Types as SIB
import           Fission.Web.Server.Host.Types
import qualified Fission.Web.Server.Relay.Store.Types      as Relay
import           Fission.Web.Server.Types

import qualified Fission.Web.Server.Heroku.ID.Types        as Hku
import qualified Fission.Web.Server.Heroku.Password.Types  as Hku

import           Fission.Web.Server.Storage.PostgreSQL

{- | Setup a config, run an action in it, and tear down the config.
     Great for quick one-offs, but anything with heavy setup
     should use 'mkConfig' or 'run'.

     == Example Use

     > runOne Network.IPFS.Peer.all
     > -- Right ["/ip4/3.215.160.238/tcp/4001/ipfs/QmVLEz2SxoNiFnuyLpbXsH6SvjPTrHNMU88vCQZyhgBzgw"]
-}
runOne :: Server a -> IO a
runOne action = do
  logOptions  <- logOptionsHandle stdout True
  processCtx  <- mkDefaultProcessContext
  httpManager <- HTTP.newManager HTTP.defaultManagerSettings
  tlsManager  <- HTTP.newManager HTTP.tlsManagerSettings

  withLogFunc (setLogUseTime True logOptions) \logFunc -> do
    withDBPool logFunc connectionInfo (PoolSize 4) \dbPool ->
      liftIO $ run logFunc dbPool processCtx httpManager tlsManager action

{- | Run some action(s) in the app's context,
     but asks for existing portions of the setup that require side effects,
     in case they're already available (which is more efficient).

     == Example Use

     > dbPool <- runApp $ connPool 1 1 3600 pgConnectInfo'
     > processCtx <- mkDefaultProcessContext
     > httpManager <- HTTP.newManager HTTP.defaultManagerSettings
     > logOptions <- logOptionsHandle stdout True
     > (logFunc,  :: IO ()) <- newLogFunc $ setLogUseTime True logOptions
     >
     > let runSession = run logFunc dbPool processCtx httpManager
     >
     > runSession Network.IPFS.Peer.all
     > -- Right ["/ip4/3.215.160.238/tcp/4001/ipfs/QmVLEz2SxoNiFnuyLpbXsH6SvjPTrHNMU88vCQZyhgBzgw"]
     >
     > runSession Network.IPFS.Peer.connect Fission.peer
     > -- ()
-}
run ::
     LogFunc
  -> Pool SqlBackend
  -> ProcessContext
  -> HTTP.Manager
  -> HTTP.Manager
  -> Server a
  -> IO a
run logFunc dbPool processCtx httpManager tlsManager action = do
  machineName       <- Network.getHostName
  linkRelayStoreVar <- atomically $ newTVar mempty
  let config = Config {..}

  runServer config do
    logDebug $ textShow config
    action

  where
    ipfsHttpManager = httpManager

    host         = Host $ BaseUrl Https "mycoolapp.io" 443 ""
    liveDriveURL = URL "fission.codes" (Just $ Subdomain "drive")

    herokuID       = Hku.ID       "HEROKU_ID"
    herokuPassword = Hku.Password "HEROKU_PASSWORD"

    fissionDID = DID
      { publicKey = Fixture.Ed25519.pk
      , method    = Key
      }

    environment = LocalDev

    baseAppZoneID  = AWS.ZoneID "BASE_APP_ZONE_ID"
    userZoneID     = AWS.ZoneID "USER_ZONE_ID"
    serverZoneID   = AWS.ZoneID "SERVER_ZONE_ID"

    userRootDomain = "userootdomain.net"

    ipfsPath        = "/usr/local/bin/ipfs"
    ipfsURLs        = Partial.fromJust $ nonEmpty [IPFS.URL $ BaseUrl Http "localhost" 5001 ""]
    ipfsTimeout     = IPFS.Timeout 3600
    ipfsRemotePeers = pure $ IPFS.Peer "/ip4/3.215.160.238/tcp/4001/ipfs/QmVLEz2SxoNiFnuyLpbXsH6SvjPTrHNMU88vCQZyhgBzgw"

    awsAccessKey   = "SOME_AWS_ACCESS_KEY"
    awsSecretKey   = "SOME_AWS_SECRET_KEY"
    awsMockRoute53 = AWS.MockRoute53 True

    baseAppDomain  = DomainName "appdomain.com"

    appPlaceholder = IPFS.CID "QmAppPlaceholder"
    defaultDataCID = IPFS.CID "QmUserData"

    sibApiKey                      = SIB.ApiKey "SEND_IN_BLUE_API_KEY"
    sibUrl                         = Host $ BaseUrl Https "notreallysendinblue.com" 443 ""
    sibVerificationEmailTemplateId = SIB.TemplateId 1
    sibRecoveryEmailTemplateId     = SIB.TemplateId 1
    sibRecoveryAppUrl              = "https://nottherealrecoveryapp.io/recover/"

{- | Setup a complete development configuration with all pure defaults set

     == Example Use

     > dbPool       <- runApp $ connPool 1 1 3600 pgConnectInfo'
     > processCtx   <- mkDefaultProcessContext
     > httpManager  <- HTTP.newManager HTTP.defaultManagerSettings
     > logOptions   <- logOptionsHandle stdout True
     > (logFunc, ) <- newLogFunc $ setLogUseTime True logOptions
     >
     > let cfg = mkConfig dbPool processCtx httpManager logFunc "testmachine"
     > let run' = runServer cfg
     >
     > run' Network.IPFS.Peer.all
     > -- Right ["/ip4/3.215.160.238/tcp/4001/ipfs/QmVLEz2SxoNiFnuyLpbXsH6SvjPTrHNMU88vCQZyhgBzgw"]
     >
     > run' Network.IPFS.Peer.connect Fission.peer
     > -- ()

     If you need to overwrite any fields: use record update syntax, or the 'Config' lenses.

     > let run' = runServer cfg { ipfsPath = "~/Downloads/ipfs" }
     > run' Network.IPFS.Peer.all
     > -- Right ["/ip4/3.215.160.238/tcp/4001/ipfs/QmVLEz2SxoNiFnuyLpbXsH6SvjPTrHNMU88vCQZyhgBzgw"]
-}
mkConfig ::
     Pool SqlBackend
  -> ProcessContext
  -> HTTP.Manager
  -> HTTP.Manager
  -> LogFunc
  -> TVar Relay.Store
  -> Network.HostName
  -> Config
mkConfig dbPool processCtx httpManager tlsManager logFunc linkRelayStoreVar machineName = Config {..}
  where
    ipfsHttpManager = httpManager

    host = Host $ BaseUrl Https "mycoolapp.io" 443 ""
    liveDriveURL = URL "fission.codes" (Just $ Subdomain "drive")

    herokuID       = Hku.ID       "HEROKU_ID"
    herokuPassword = Hku.Password "HEROKU_PASSWORD"

    fissionDID = DID
      { publicKey = Fixture.Ed25519.pk
      , method    = Key
      }

    ipfsPath        = "/usr/local/bin/ipfs"
    ipfsURLs        = Partial.fromJust $ nonEmpty [IPFS.URL $ BaseUrl Http "localhost" 5001 ""]
    ipfsRemotePeers = pure $ IPFS.Peer "/ip4/3.215.160.238/tcp/4001/ipfs/QmVLEz2SxoNiFnuyLpbXsH6SvjPTrHNMU88vCQZyhgBzgw"
    ipfsTimeout     = IPFS.Timeout 3600

    baseAppZoneID  = AWS.ZoneID "BASE_APP_ZONE_ID"
    userZoneID     = AWS.ZoneID "USER_ZONE_ID"
    serverZoneID   = AWS.ZoneID "SERVER_ZONE_ID"

    environment    = LocalDev
    userRootDomain = "userootdomain.net"

    awsAccessKey   = "SOME_AWS_ACCESS_KEY"
    awsSecretKey   = "SOME_AWS_SECRET_KEY"
    awsMockRoute53 = AWS.MockRoute53 True

    baseAppDomain  = DomainName "appdomain.com"

    appPlaceholder = IPFS.CID "QmAppPlaceholder"
    defaultDataCID = IPFS.CID "QmUserData"

    sibApiKey                      = SIB.ApiKey "SEND_IN_BLUE_API_KEY"
    sibUrl                         = Host $ BaseUrl Https "notreallysendinblue.com" 443 ""
    sibVerificationEmailTemplateId = SIB.TemplateId 1
    sibRecoveryEmailTemplateId     = SIB.TemplateId 1
    sibRecoveryAppUrl              = "https://nottherealrecoveryapp.io/recover/"


{- | Setup a complete development configuration.

     Note that this does not clean up the log function,
     but does return an action to do so.

     == Example Use

     > (cfg, ) <- mkConfig'
     > let run' = runServer cfg
     > run' Network.IPFS.Peer.all
     > -- Right ["/ip4/3.215.160.238/tcp/4001/ipfs/QmVLEz2SxoNiFnuyLpbXsH6SvjPTrHNMU88vCQZyhgBzgw"]
     >
     > run' Network.IPFS.Peer.connect Fission.peer
     > -- ()

     If you need to overwrite any fields: use record update syntax, or the 'Config' lenses.

     > (cfg, ) <- mkConfig'
     > let run' = runServer cfg { ipfsPath = "~/Downloads/ipfs" }
     > run' Network.IPFS.Peer.all
     > -- Right ["/ip4/3.215.160.238/tcp/4001/ipfs/QmVLEz2SxoNiFnuyLpbXsH6SvjPTrHNMU88vCQZyhgBzgw"]
-}
mkConfig' :: IO (Config, IO ())
mkConfig' = do
  processCtx        <- mkDefaultProcessContext
  httpManager       <- HTTP.newManager HTTP.defaultManagerSettings
  tlsManager        <- HTTP.newManager HTTP.tlsManagerSettings
  linkRelayStoreVar <- atomically $ newTVar mempty

  -- A bit dirty; doesn't directly handle teardown
  (logFunc, close) <- newLogFunc . setLogUseTime True =<< logOptionsHandle stdout True
  machineName      <- Network.getHostName

  withDBPool logFunc connectionInfo (PoolSize 4) \dbPool -> do
    let cfg = mkConfig dbPool processCtx httpManager tlsManager logFunc linkRelayStoreVar machineName
    return (cfg, close)

connectionInfo :: ConnectionInfo
connectionInfo = ConnectionInfo
  { pgDatabase = "web_api"
  , pgHost     = "localhost"
  , pgPort     = 5432
  , pgUsername = Nothing
  , pgPassword = Nothing
  }
