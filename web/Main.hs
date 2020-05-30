module Main (main) where

import qualified Data.Aeson as JSON
import qualified Data.Yaml  as YAML

import qualified Network.HTTP.Client as HTTP
import           Servant

import           Network.Wai.Handler.Warp
import           Network.Wai.Handler.WarpTLS
import           Network.Wai.Middleware.RequestLogger

import qualified RIO

import           Fission
import           Fission.Prelude
import           Fission.Storage.PostgreSQL
import qualified Fission.Authorization.ServerDID.Class as ServerDID
import           Fission.Internal.App

import qualified Fission.Web       as Web
import qualified Fission.Web.Log   as Web.Log
import qualified Fission.Web.Types as Web

import qualified Fission.Web.Middleware.CORS as CORS

import qualified Fission.Platform.Heroku.AddOn.Manifest.Types as Hku
import qualified Fission.Platform.Heroku.ID.Types             as Hku
import qualified Fission.Platform.Heroku.Password.Types       as Hku

import           Fission.Environment.IPFS.Types    as IPFS
import           Fission.Environment.Types

import qualified Fission.Environment.Auth.Types    as Auth
import qualified Fission.Environment.AWS.Types     as AWS
import qualified Fission.Environment.FFS.Types     as FFS
import qualified Fission.Environment.Storage.Types as Storage
import qualified Fission.Environment.Web.Types     as Web
import qualified Fission.Environment.WebApp.Types  as WebApp

import qualified Fission.Web.Log.Sentry as Sentry

import           Fission.Web.Handler
import           Fission.Web.Auth as Auth

main :: IO ()
main = do
  Just  manifest <- JSON.decodeFileStrict "./addon-manifest.json"
  env            <- YAML.decodeFileThrow  "./env.yaml"

  let
    AWS.Environment     {..} = env |> aws
    Auth.Environment    {..} = env |> auth
    FFS.Environment     {..} = env |> ffs
    Storage.Environment {..} = env |> storage
    Web.Environment     {..} = env |> web
    WebApp.Environment  {..} = env |> webApp
   
    herokuID       = Hku.ID       . encodeUtf8 $ Hku.id manifest
    herokuPassword = Hku.Password . encodeUtf8 . Hku.password $ Hku.api manifest

    ipfsPath       = env |> ipfs |> binPath
    ipfsURL        = env |> ipfs |> url
    ipfsRemotePeer = env |> ipfs |> remotePeer
    ipfsTimeout    = env |> ipfs |> IPFS.timeout
    ipfsGateway    = env |> ipfs |> gateway

    awsAccessKey          = accessKey
    awsSecretKey          = secretKey
    awsZoneID             = zoneID
    awsRoute53MockEnabled = route53MockEnabled

  isVerbose  <- isDebugEnabled
  logOptions <- logOptionsHandle stdout isVerbose

  processCtx  <- mkDefaultProcessContext
  httpManager <- HTTP.newManager HTTP.defaultManagerSettings
                   { HTTP.managerResponseTimeout = HTTP.responseTimeoutMicro clientTimeout }

  condSentryLogger <- maybe (pure mempty) (Sentry.mkLogger RIO.LevelWarn) sentryDSN

  withLogFunc (setLogUseTime True logOptions) \baseLogger -> do
    let
      logFunc        = baseLogger <> condSentryLogger
      Web.Port port' = port
      settings       = mkSettings logFunc port'
      runner         = if env |> web |> Web.isTLS then runTLS tlsSettings' else runSettings
      condDebug      = if env |> web |> Web.pretty then identity else logStdoutDev

    withDBPool baseLogger pgConnectInfo (PoolSize 4) \dbPool -> do
      let cfg = Config {..}
      runFission cfg do
        logDebug . displayShow =<< ask

        logInfo ("Ensuring live DB matches latest schema" :: Text)
        runDB updateDBToLatest

        auth <- Auth.mkAuth
        logDebug @Text $ layoutWithContext (Proxy @Web.API) auth

        ServerDID.publicize

        host
          |> Web.app (toHandler (runFission cfg)) auth
          |> condDebug
          |> CORS.middleware
          |> runner settings
          |> liftIO

mkSettings :: LogFunc -> Port -> Settings
mkSettings logger port =
  defaultSettings
    |> setPort port
    |> setLogger (Web.Log.fromLogFunc logger)
    |> setTimeout serverTimeout

tlsSettings' :: TLSSettings
tlsSettings' = tlsSettings "domain-crt.txt" "domain-key.txt"

clientTimeout :: Int
clientTimeout = 1800000000

serverTimeout :: Int
serverTimeout = 1800
