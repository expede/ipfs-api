module Fission.CLI.Handler.User.Login (Errs, login) where

import           Crypto.Cipher.AES                           (AES256)
-- import           Crypto.Cipher.Types
import           Crypto.Error                                as Crypto
-- import           Crypto.Hash.Algorithms
-- import qualified Crypto.PubKey.Ed25519                       as Ed25519
-- import qualified Crypto.PubKey.RSA.OAEP                            as RSA.OAEP
import qualified Crypto.PubKey.RSA.Types                     as RSA
import           Crypto.Random

-- import           Data.ByteArray                                    hiding (all,
   --                                                                  and, any,
      --                                                               length, or)
-- import qualified Data.ByteString.Base64                            as Base64
-- import qualified Data.ByteString.Base64.URL                        as Base64.URL
-- import qualified Data.ByteString.Char8                             as C8

-- import qualified RIO.ByteString.Lazy                               as Lazy
-- import qualified RIO.Text                                          as Text

import qualified Network.DNS                                 as DNS
import           Servant.Client.Core

import           Fission.Prelude

-- import qualified Fission.Internal.Base64                           as B64
-- import qualified Fission.Internal.Base64.URL                       as B64.URL
import qualified Fission.Internal.UTF8                       as UTF8

import           Fission.Error.Types

import qualified Fission.JSON                                as JSON

import           Fission.Emoji.Class

-- import           Fission.Key.EncryptedWith.Types
import           Fission.Key.IV.Error                        as IV

-- import           Fission.Authorization.Potency.Types
-- import           Fission.Authorization.ServerDID

import           Fission.User.DID.NameService.Class          as DID
import           Fission.User.DID.Types
import           Fission.User.Username.Types                 as User

import           Fission.Web.Auth.Token.JWT.Fact.Types
import qualified Fission.Web.Auth.Token.JWT.Proof            as UCAN

import           Fission.Web.Client
-- import qualified Fission.Web.Client.User                           as User

import           Fission.Key.Asymmetric.Public.Types
import qualified Fission.Key.Symmetric                       as Symmetric

import           Fission.Web.Auth.Token.Bearer.Types         as Bearer
import           Fission.Web.Auth.Token.JWT                  as JWT
import qualified Fission.Web.Auth.Token.JWT                  as UCAN
import qualified Fission.Web.Auth.Token.JWT.Claims.Error     as JWT.Claims
import qualified Fission.Web.Auth.Token.JWT.Error            as JWT
import qualified Fission.Web.Auth.Token.JWT.Proof.Error      as JWT.Proof
import qualified Fission.Web.Auth.Token.JWT.Resolver.Class   as JWT
import qualified Fission.Web.Auth.Token.JWT.Resolver.Error   as UCAN.Resolver
import qualified Fission.Web.Auth.Token.JWT.Validation       as UCAN
-- import qualified Fission.Web.Auth.Token.Types                as Auth

-- import           Fission.CLI.Display.Success                       as CLI.Success
import           Fission.CLI.Environment                     as Env
import           Fission.CLI.Remote

import qualified Fission.CLI.Key.Store                       as Key.Store
import           Fission.CLI.Key.Store.Types
import           Fission.CLI.PIN                             as PIN
import           Fission.CLI.PubSub                          as PubSub
import           Fission.CLI.PubSub.Secure
import           Fission.CLI.PubSub.Secure.Connection        as Secure
import           Fission.CLI.PubSub.Secure.Payload
-- import qualified Fission.CLI.PubSub.Secure.Payload.AES.Types       as AES
import qualified Fission.CLI.PubSub.Secure.Payload.Error     as SecurePayload
-- import qualified Fission.CLI.PubSub.Secure.Session.Handshake.Types as Session
import qualified Fission.CLI.PubSub.Secure.Session.Types     as PubSub

import qualified Fission.CLI.WebNative.FileSystem.Auth.Store as WebNative.FileSystem.Auth.Store
import qualified Fission.CLI.WebNative.Mutation.Auth.Store   as WebNative.Mutation.Store

-- import           Fission.CLI.Digit.Types

import qualified Fission.CLI.PIN.Payload.Types               as PIN

-- import qualified Fission.CLI.User                                  as User
import qualified Fission.CLI.User.Link.Payload.Types         as User.Link

type Errs =
  '[ AlreadyExists DID
   , ClientError
   , CryptoError
   , IV.GenError
   , JSON.Error
   , JWT.Error
   , JWT.Proof.Error
   , Key.Store.Error
   , NotFound DID
   , RSA.Error
   , SecurePayload.Error
   , UCAN.Resolver.Error
   ]

login ::
  ( MonadLogger       m
  , MonadRemote       m
  , MonadTime         m
  , MonadIO           m

  , JWT.Resolver      m
 -- , ServerDID m

  , WebNative.FileSystem.Auth.Store.MonadStore m
  , WebNative.Mutation.Store.MonadStore        m

  -- , MonadNameService    m
  -- , MonadPubSub m

  , MonadSecured m (Symmetric.Key AES256) PIN.Payload
  , MonadSecured m (Symmetric.Key AES256) User.Link.Payload
  , MonadSecured m RSA.PrivateKey PubSub.Session

  , MonadPubSubSecure m RSA.PrivateKey
  --, MonadPubSubSecure m (Symmetric.Key AES256)

  -- , MonadWebAuth m Auth.Token
  -- , MonadWebAuth m Ed25519.SecretKey


  , MonadRandom      m
  , MonadEnvironment m
  , MonadNameService m
  , MonadWebClient   m

  , MonadCleanup m
 --  , m `Raises` AlreadyExists DID
  , m `Raises` ClientError
  , m `Raises` DNS.DNSError
  -- , m `Raises` CryptoError
  -- , m `Raises` IV.GenError
  , m `Raises` JSON.Error
  , m `Raises` JWT.Error
  , m `Raises` JWT.Proof.Error
  , m `Raises` Key.Store.Error
  , m `Raises` NotFound DID
  -- , m `Raises` RSA.Error
  , m `Raises` SecurePayload.Error
  , m `Raises` UCAN.Resolver.Error

  , Show (OpenUnion (Errors m))
  , Display (SecurePayload (Symmetric.Key AES256) User.Link.Payload)
  )
  => Username
  -> m ()
login username = do
  -- FIXME User.ensureNotLoggedIn / switch on login vs provide

  signingSK <- Key.Store.fetch $ Proxy @SigningKey
  signingPK <- Key.Store.toPublic (Proxy @SigningKey) signingSK
  targetDID <- ensureM $ DID.getByUsername username

  rootURL <- getRemoteBaseUrl

  let
    myDID   = DID Key (Ed25519PublicKey signingPK)
    topic   = PubSub.Topic $ textDisplay targetDID
    baseURL = rootURL {baseUrlPath = "/user/link"} -- NOTE hardcoded and not using safeLink
                                                   --      since that would cause a dependency on fission-web-server

  PubSub.connect baseURL topic \conn -> reattempt 10 do
    logDebug @Text "🤝 Device linking handshake: Step 1"
    aesConn <- secure conn () \rsaConn@Secure.Connection {key} -> reattempt 10 do
      let
        sessionDID = DID Key (RSAPublicKey $ RSA.private_pub key)

      logDebug @Text "🤝 Device linking handshake: Step 2"
      broadcastRaw conn sessionDID

      reattempt 10 do
        logDebug @Text "🤝 Device linking handshake: Step 3"
        PubSub.Session
          { bearerToken = Bearer.Token {jwt, rawContent}
          , sessionKey
          } <- secureListenJSON rsaConn

        logDebug @Text "🤝 Device linking handshake: Step 4"
        ensureM $ UCAN.check sessionDID rawContent jwt
        -- FIXME waiting on FE to not send an append UCAN -- case (jwt |> claims |> potency) == AuthNOnly of
        ensure $ UCAN.containsFact jwt \facts ->
          if any (== SessionKey sessionKey) facts
            then Right ()
            else Left JWT.Proof.MissingExpectedFact

        return Secure.Connection {conn, key = sessionKey}

    logDebug @Text "🤝 Device linking handshake: Step 5"
    pinStep <- PIN.Payload myDID <$> PIN.create

    UTF8.putTextLn $ "Confirmation code: " <> toEmoji pinStep
    secureBroadcastJSON aesConn pinStep

    reattempt 100 do
      logDebug @Text "🤝 Device linking handshake: Step 6"
      User.Link.Payload
        { bearer = bearer@Bearer.Token {jwt, rawContent}
        , readKey
        } <- secureListenJSON aesConn

      ensureM $ UCAN.check myDID rawContent jwt
      JWT {claims = JWT.Claims {sender}} <- ensureM $ UCAN.getRoot jwt

      unless (sender == targetDID) do
        raise $ JWT.ClaimsError JWT.Claims.IncorrectSender

      -- Persist credentials
      _   <- WebNative.FileSystem.Auth.Store.set targetDID "/" readKey
      cid <- WebNative.Mutation.Store.insert bearer

      Env.init username baseURL (Just cid)
