-- | Delegate capabilities to a DID
module Fission.CLI.Handler.App.Delegate (delegate) where

import qualified Crypto.PubKey.Ed25519                            as Ed25519

import           Crypto.Random.Types

import qualified Data.ByteString.Base64                           as Base64
import qualified Data.ByteString.Char8                            as Char8

import           Data.Function
import qualified Data.Yaml                                        as YAML

import qualified RIO.Text                                         as Text
import qualified RIO.Map                                          as Map

import qualified System.Console.ANSI                              as ANSI
import qualified System.Environment                               as Env

import           Fission.Prelude

import           Fission.Authorization.ServerDID

import           Fission.CLI.Display.Text
import qualified Fission.CLI.Display.Error                        as CLI.Error
import qualified Fission.CLI.Display.Success                      as CLI.Success
import           Fission.CLI.Environment
import           Fission.CLI.Key.Store                            as Key.Store
import           Fission.CLI.WebNative.Mutation.Auth.Store

import           Fission.Error

import           Fission.Internal.UTF8                            as UTF8

import qualified Fission.Key                                      as Key

import           Fission.Web.Auth.Token.Types
import qualified Fission.Web.Auth.Token.UCAN                      as UCAN
import           Fission.Web.Auth.Token.UCAN.Types
import           Fission.Web.Auth.Token.UCAN.Fact.Types
import           Fission.Web.Auth.Token.UCAN.Resource.Types
import           Fission.Web.Auth.Token.UCAN.Resource.Scope.Types
import           Fission.Web.Auth.Token.UCAN.Potency.Types
import           Fission.Web.API.App.Index.Payload.Types
import           Fission.Web.Client

import           Fission.URL

import           Web.DID.Types                                    as DID

import qualified Web.UCAN                                         as UCAN
import qualified Web.UCAN.Internal.Base64.Scrubbed                as B64
import           Web.UCAN.Internal.Base64.URL                     as B64
import           Web.UCAN.Resolver                                as UCAN.Resolver
import qualified Web.UCAN.Types                                   as UCAN.Types
import           Web.UCAN.Proof                                   as UCAN.Proof
import qualified Web.UCAN.RawContent                              as UCAN.RawContent
import           Web.UCAN.Validation                              (check', checkTime)


-- | Delegate capabilities to a DID
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
  , m `Raises` NotFound Ed25519.SecretKey
  , m `Raises` NotFound FilePath
  , m `Raises` NotFound UCAN
  , m `Raises` NotFound URL
  , m `Raises` ParseError DID
  , m `Raises` ParseError UCAN
  , m `Raises` UCAN.Resolver.Error
  , m `Raises` UCAN.Proof.Error
  , m `Raises` UCAN.Error

  , UCAN.Resolver.Resolver m

  , Contains (Errors m) (Errors m)
  , Display  (OpenUnion (Errors m))
  , Show     (OpenUnion (Errors m))

  , MonadWebAuth m Token
  , MonadWebAuth m Ed25519.SecretKey
  )
  => Text
  -> Either String DID
  -> Int
  -> m ()
delegate appName audienceDid lifetimeInSeconds = do
    logDebug @Text "delegate"

    case audienceDid of
      Left err -> do
        CLI.Error.put err "Could not parse DID"
        raise $ ParseError @DID

      Right did -> do
        logDebug $ "Audience DID: " <> textDisplay did

        let
          -- Add support for staging, check remote flag
          url = URL { domainName = "fission.app", subdomain = Just $ Subdomain appName}
          appResource = Subset $ FissionApp (Subset url)

        attempt (getCredentialsFor appName appResource) >>= \case
          Left err ->
            raise err

          Right (signingKey, proof) -> do
            now <- getCurrentTime

            let 
              ucan = delegateAppendApp appResource did signingKey proof lifetimeInSeconds now
              encodedUcan = encodeUcan ucan

            CLI.Success.putOk $ "Delegated a UCAN for " <> appName <> " to " <> textDisplay did 
            UTF8.putText "🎫 UCAN: "
            colourized [ANSI.SetColor ANSI.Foreground ANSI.Vivid ANSI.Blue] do
              UTF8.putTextLn $ textDisplay encodedUcan


getCredentialsFor ::
  ( MonadIO          m
  , MonadLogger      m 
  , MonadRandom      m
  , MonadTime        m

  , MonadEnvironment m
  , MonadStore       m
  , MonadWebClient   m
  , ServerDID        m

  , MonadCleanup     m
  , m `Raises` ClientError
  , m `Raises` Key.Error
  , m `Raises` YAML.ParseException
  , m `Raises` NotFound Ed25519.SecretKey
  , m `Raises` NotFound FilePath
  , m `Raises` NotFound UCAN
  , m `Raises` NotFound URL
  , m `Raises` ParseError UCAN
  , m `Raises` UCAN.Resolver.Error
  , m `Raises` UCAN.Proof.Error
  , m `Raises` UCAN.Error

  , UCAN.Resolver.Resolver m

  , Contains (Errors m) (Errors m)
  , Display  (OpenUnion (Errors m))
  , Show     (OpenUnion (Errors m))

  , MonadWebAuth m Token
  , MonadWebAuth m Ed25519.SecretKey
  ) 
  => Text 
  -> Scope Resource
  -> m (SecretKey SigningKey, Proof)
getCredentialsFor appName appResource = do
  maySigningKey <- liftIO $ Env.lookupEnv "FISSION_MACHINE_KEY"
  mayAppUcan    <- liftIO $ Env.lookupEnv "FISSION_APP_UCAN"

  logDebug $ "FISSION_MACHINE_KEY: " <> show maySigningKey
  logDebug $ "FISSION_APP_UCAN: " <> show mayAppUcan

  case (maySigningKey, mayAppUcan) of
    (Just key, Just appUcan) -> do
      -- Sign with key, use appUcan as proof
      let
        rawKey = B64.scrub $ Base64.decodeLenient $ Char8.pack key

      attempt (checkProofEnvVar appUcan appResource) >>= \case
        Left err -> do
          raise err

        Right ucan -> do
          let
              tokenBS = Char8.pack $ wrapIn "\"" appUcan
              rawContent = UCAN.RawContent.contentOf (decodeUtf8Lenient tokenBS)
              proof = UCAN.Types.Nested rawContent ucan

          logDebug $ "Delegating with FISSION_APP_UCAN: " <> show ucan
          signingKey <- ensureM $ Key.Store.parse (Proxy @SigningKey) rawKey
          return (signingKey, proof)

    (Just _, Nothing) -> do
      CLI.Error.put (Text.pack "Not Found") "FISSION_APP_UCAN must be set when delegating with environment variables."
      raise $ NotFound @UCAN

    (Nothing, Just _) -> do
      CLI.Error.put (Text.pack "Not Found") "FISSION_MACHINE_KEY must be set when delegating with environment variables."
      raise $ NotFound @Ed25519.SecretKey

    (Nothing, Nothing) -> do
      -- Use normal CLI config from keystore
      signingKey <- Key.Store.fetch $ Proxy @SigningKey
      proof <- getRootUserProof

      attempt (checkProofConfig proof appName)  >>= \case
        Left err ->
          raise err

        Right prf -> do
          return (signingKey, prf)


checkProofEnvVar ::
  ( MonadIO          m
  , MonadLogger      m
  , MonadRescue      m

  , UCAN.Resolver.Resolver m

  , m `Raises` ParseError UCAN
  , m `Raises` UCAN.Proof.Error
  , m `Raises` UCAN.Error

  )
  => String
  -> Scope Resource
  -> m UCAN 
checkProofEnvVar token requestedResource = do
  let
    tokenBS = Char8.pack $ wrapIn "\"" token

  case UCAN.parse tokenBS of
    Left err -> do
      CLI.Error.put err "Unable to parse UCAN set in FISSION_APP_UCAN environment variable"
      raise $ ParseError @UCAN
          
    Right ucan -> do
      logDebug $ "Parsed UCAN: " <> textDisplay ucan

      if hasCapability requestedResource ucan then do
        let
          rawContent = UCAN.RawContent.contentOf (decodeUtf8Lenient tokenBS)

        now <- getCurrentTime
        ensure $ checkTime now ucan
        ensureM $ check' rawContent ucan now
        return ucan

      else do
        CLI.Error.put (Text.pack "Unable to delegate") "UCAN does not have sufficient capabilities to delegate."
        raise ScopeOutOfBounds


checkProofConfig ::
  ( MonadIO          m
  , MonadLogger      m
  , MonadTime        m

  , MonadWebClient   m
  , ServerDID        m

  , UCAN.Resolver.Resolver m

  , MonadCleanup     m
  , m `Raises` ClientError
  , m `Raises` NotFound URL
  , m `Raises` UCAN.Resolver.Error
  , m `Raises` UCAN.Error

  , MonadWebAuth m Token
  , MonadWebAuth m Ed25519.SecretKey

  , Contains (Errors m) (Errors m)
  , Display  (OpenUnion (Errors m))
  , Show     (OpenUnion (Errors m))
  )
  => Proof
  -> Text
  -> m Proof 
checkProofConfig proof appName = do
  case proof of
    UCAN.Types.RootCredential -> do
      appRegistered <- checkAppRegistration appName proof

      if appRegistered then
        return proof

      else do
        CLI.Error.put (Text.pack "Not Found") $
          "Unable to find an app named " <> appName <>
          ". Is the name right and have you registered it?"
        raise $ NotFound @URL


    UCAN.Types.Nested rawContent prf -> do
      now <- getCurrentTime
      ensure $ checkTime now prf
      ensureM $ check' rawContent prf now
      return proof

    UCAN.Types.Reference cid -> do
      let
        parseToken :: ByteString -> Either UCAN.Resolver.Error (UCAN.Types.UCAN Fact (Scope Resource) Potency)
        parseToken bs =  UCAN.parse bs

      proofTokenBS <- ensureM $ UCAN.Resolver.resolve cid
      prf <- ensure $ parseToken proofTokenBS

      let
        rawContent = UCAN.RawContent.contentOf (decodeUtf8Lenient proofTokenBS)

      now <- getCurrentTime
      ensure $ checkTime now prf
      ensureM $ check' rawContent prf now
      return proof


hasCapability ::
  Scope Resource
  -> UCAN
  -> Bool
hasCapability requestedResource ucan = do
  let
    UCAN.Types.UCAN {claims = UCAN.Types.Claims {resource = mayResource, potency = mayPotency}} = ucan

  case mayResource of
    Just rsc ->
      rsc `canDelegate` requestedResource &&
        case mayPotency of
          Just ptc ->
            ptc `canDelegate` AppendOnly

          Nothing ->
            False

    Nothing ->
      False


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


delegateAppendApp :: Scope Resource -> DID -> Ed25519.SecretKey -> Proof -> Int -> UTCTime -> UCAN
delegateAppendApp resource targetDID sk proof lifetime now =
  UCAN.mkUCAN targetDID sk start expire [] (Just resource) (Just AppendOnly) proof
    where
      start  = addUTCTime (secondsToNominalDiffTime (-30))                    now
      expire = addUTCTime (secondsToNominalDiffTime (fromIntegral lifetime))  now


encodeUcan :: UCAN -> Text
encodeUcan UCAN.Types.UCAN {..} =
  let
    rawContent = UCAN.RawContent $ B64.encodeJWT header claims
  in
  textDisplay rawContent <> "." <> textDisplay sig
