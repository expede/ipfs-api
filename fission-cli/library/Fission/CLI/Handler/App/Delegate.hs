-- | Delegate capabilities to a key pair or DID
module Fission.CLI.Handler.App.Delegate (delegate) where

import qualified Crypto.PubKey.Ed25519                     as Ed25519

import           Crypto.Random.Types
import           Data.Function
import qualified Data.Yaml                                 as YAML
import qualified RIO.Text                                  as Text
import qualified RIO.Map                                   as Map

import qualified System.Environment                        as Env

import           Fission.Prelude

import qualified Fission.Key                                 as Key
import           Fission.URL

import qualified Fission.App.Name                            as App

import           Fission.Authorization.ServerDID

import           Fission.Error.Types

import           Fission.CLI.Key.Store                       as Key.Store
import           Fission.Web.Auth.Token.Types
import           Fission.Web.Auth.Token.UCAN.Types
import           Fission.Web.Client

import qualified Fission.CLI.Display.Error                 as CLI.Error
import qualified Fission.CLI.Display.Success               as CLI.Success
import           Fission.CLI.Key.Ed25519

import           Fission.CLI.Environment
import           Fission.CLI.WebNative.Mutation.Auth.Store

import qualified Fission.Web.Auth.Token.UCAN                      as UCAN
import           Fission.Web.Auth.Token.UCAN.Resource.Types
import           Fission.Web.Auth.Token.UCAN.Resource.Scope.Types
import           Fission.Web.Auth.Token.UCAN.Potency.Types
import           Fission.Web.API.App.Index.Payload.Types
-- import qualified Fission.Web.Auth.Token.Bearer                    as Bearer (fromJWT)
 

import           Web.DID.Types                              as DID


import qualified Web.UCAN                                   (fromRawContent)
import qualified Web.UCAN.Internal.Base64                   as B64
import qualified Web.UCAN.Internal.Base64.Scrubbed          as B64.Scrubbed

import           Web.UCAN.Internal.Base64.URL               as B64.URL
import qualified Web.UCAN.Types                             as UCAN.Types


-- | Delegate capabilities to a key pair or DID
delegate ::
  ( MonadIO          m
  , MonadLogger      m 
  , MonadRandom m
  , MonadTime        m

  , MonadEnvironment m
  , MonadStore  m
  , MonadWebClient   m
  , ServerDID        m

  , MonadCleanup     m
  , m `Raises` ClientError
  , m `Raises` Key.Error
  , m `Raises` YAML.ParseException
  , m `Raises` NotFound FilePath

  , Contains (Errors m) (Errors m)
  , Display  (OpenUnion (Errors m))
  , Show     (OpenUnion (Errors m))

  , MonadWebAuth m Token
  , MonadWebAuth m Ed25519.SecretKey
  )
  => Text
  -> Maybe DID
  -> Int
  -> m ()
delegate appName mayAudienceDid lifetimeInSeconds = do
    logDebug @Text "delegate"

    logDebug $ "Maybe DID: " <> show mayAudienceDid
    logDebug $ "Lifetime: " <> show lifetimeInSeconds

    maySigningKey <- liftIO $ Env.lookupEnv "FISSION_MACHINE_KEY"
    mayAppUcan <- liftIO $ Env.lookupEnv "FISSION_APP_UCAN"

    logError $ "FISSION_MACHINE_KEY: " <> show maySigningKey
    logError $ "FISSION_APP_UCAN: " <> show mayAppUcan

    (signingKey, proof) <- case (maySigningKey, mayAppUcan) of
      (Just key, Just appUcan) -> do
        -- Sign with key, use appUcan as proof

        let
          rawKey = B64.Scrubbed.scrub (encodeUtf8 (Text.pack key))
          maybeUcan = checkProofToken appUcan

        logError $ "UCAN Result: " <> show maybeUcan

        -- return (signingKey, proof)

        signingKey <- ensureM $ Key.Store.parse (Proxy @SigningKey) rawKey
        return (signingKey, UCAN.Types.RootCredential)
      (Just key, Nothing) -> do
        -- Sign with key, assume key has root authority
        let
          rawKey = B64.Scrubbed.scrub (encodeUtf8 (Text.pack key))

        signingKey <- ensureM $ Key.Store.parse (Proxy @SigningKey) rawKey
        return (signingKey, UCAN.Types.RootCredential)

      (Nothing, _) -> do
        -- Use normal CLI config from keystore
        signingKey <- Key.Store.fetch $ Proxy @SigningKey
        proof <- getRootUserProof
        return (signingKey, proof)

    appRegistered <- checkAppRegistration appName proof

    if appRegistered then do
      logDebug $ appName <> " is registered!"

      case mayAudienceDid of
        Just audienceDid ->
          logDebug $ textDisplay audienceDid <> " is the audience DID"

        Nothing -> do
          logDebug @Text "🏗️  Generating signing key"

          secretKey <- Ed25519.generateSecretKey
          now <- getCurrentTime

          let 
            publicKey = Ed25519.toPublic secretKey
            did = DID.Key $ Key.Ed25519PublicKey publicKey
            ucan = delegateAppendApp appName did signingKey proof now
            encodedUcan = encodeUcan ucan

          logDebug $ "Secret key " <> decodeUtf8Lenient (B64.toB64ByteString secretKey)
          logDebug $ "Public key " <> textDisplay publicKey
          logDebug $ "DID " <> textDisplay did
          logDebug $ "UCAN " <> textDisplay encodedUcan 

    else
      logDebug $ appName <> " is not registered."


checkProofToken :: String  -> Either Text UCAN
checkProofToken token =
  let
    rawContent = UCAN.contentOf (Text.pack token)
  in

  case Web.UCAN.fromRawContent rawContent of
    Left err -> 
      -- raise err
      Left $ textDisplay err
          
    Right ucan ->
      -- Do more to check and return a UCAN.Proof
      Right ucan 
  

checkAppRegistration :: 
  ( MonadIO          m
  , MonadLogger      m 
  , MonadTime        m

  , MonadWebClient   m
  , ServerDID        m

  , MonadCleanup     m
  , m `Raises` ClientError

  , Contains (Errors m) (Errors m)
  , Display  (OpenUnion (Errors m))
  , Show     (OpenUnion (Errors m))

  , MonadWebAuth m Token
  , MonadWebAuth m Ed25519.SecretKey
  )
  => Text 
  -> Proof 
  -> m Bool 
checkAppRegistration appName proof = do
    attempt (sendAuthedRequest proof appIndex) >>= \case
      Left err -> do
        logDebug $ textDisplay err
        CLI.Error.put err $ textDisplay err
        raise err

      Right index -> do
        let
          registered = 
            Map.elems index
              & concatMap (\Payload { urls } -> urls)
              & fmap (fst . Text.break (== '.') . textDisplay)
              & elem appName

        return registered


delegateAppendApp :: Text -> DID -> Ed25519.SecretKey -> Proof -> UTCTime -> UCAN
delegateAppendApp appName targetDID sk proof now =
  let
    url = URL { domainName = "fission.app", subdomain = Just $ Subdomain appName}
    resource = FissionApp (Subset url)
    scope = Subset resource

  in
  UCAN.mkUCAN targetDID sk start expire [] (Just scope) (Just AppendOnly) proof
    where
      start  = addUTCTime (secondsToNominalDiffTime (-30)) now
      expire = addUTCTime (nominalDay * 365)         now


encodeUcan :: UCAN -> Text
encodeUcan UCAN.Types.UCAN {..} =
  let
    rawContent = UCAN.RawContent $ B64.URL.encodeJWT header claims
  in
  textDisplay rawContent <> "." <> textDisplay sig