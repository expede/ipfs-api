{-# LANGUAGE ScopedTypeVariables #-}
module Web.UCAN.Types
  ( UCAN (..)
  , Claims (..)
  , EncodedProof  (..)

  , signEd25519
  , signRS256

  -- * reexports

  , module Web.UCAN.Header.Types
  , module Web.UCAN.RawContent
  ) where

import qualified System.IO.Unsafe                              as Unsafe

import           Crypto.Hash.Algorithms                        (SHA256 (..))
import           Crypto.Random                                 (MonadRandom (..))

import qualified Crypto.PubKey.RSA                             as RSA
import qualified Crypto.PubKey.RSA.PKCS15                      as RSA.PKCS15

import           Crypto.PubKey.Ed25519                         (toPublic)
import qualified Crypto.PubKey.Ed25519                         as Ed25519

import           Data.Aeson
import qualified Data.Aeson.Types                              as JSON
import qualified Data.ByteString.Base64.URL                    as BS.B64.URL
import qualified Data.Text.Encoding.Base64.URL                 as Text.B64.URL

import           Network.IPFS.CID.Types

import           Control.Monad                                 (replicateM)
import           RIO                                           hiding (exp)
import qualified RIO.ByteString.Lazy                           as Lazy
import qualified RIO.Text                                      as Text
import           RIO.Time

import qualified Servant.API                                   as Servant


import           Test.QuickCheck


import           Crypto.Key.Asymmetric                         as Key
import qualified Crypto.Key.Asymmetric.Algorithm.Types         as Algorithm

import           Web.DID.Types                                 as DID

import           Web.UCAN.Header.Types                         (Header (..))
import           Web.UCAN.Signature                            as Signature
import qualified Web.UCAN.Signature.RS256.Types                as RS256

import qualified Web.UCAN.Internal.Base64.URL                  as B64.URL
import           Web.UCAN.Internal.Orphanage.Ed25519.SecretKey ()
import qualified Web.UCAN.Internal.RSA2048.Pair.Types          as RSA2048
import           Web.UCAN.Internal.Time
import qualified Web.UCAN.Internal.UTF8                        as UTF8


-- Reexports

import           Web.UCAN.RawContent


-- | An RFC 7519 extended with support for Ed25519 keys,
--     and some specifics (claims, etc) for Fission's use case
data UCAN fct cap = UCAN
  { header     :: Header
  , claims     :: Claims fct cap
  , signedData :: RawContent
  , sig        :: Signature.Signature
  } deriving (Show, Eq, Functor)


instance Display (UCAN fct cap) where
  textDisplay UCAN{..} =
    textDisplay signedData <> "." <> textDisplay sig


instance
  ( Arbitrary fct
  , Arbitrary cap
  , ToJSON fct
  , ToJSON cap
  ) => Arbitrary (UCAN fct cap) where
  arbitrary = do
    header   <- arbitrary
    (pk, sk) <- case alg header of
      Algorithm.RSA2048 -> do
        RSA2048.Pair pk' sk' <- arbitrary
        return (RSAPublicKey pk', Left sk')

      Algorithm.Ed25519 -> do
        sk' <- arbitrary
        return (Ed25519PublicKey (toPublic sk'), Right sk')

    claims' <- arbitrary

    let claims = claims' {sender = DID.Key pk}

    return case sk of
      Left rsaSK ->
        case Unsafe.unsafePerformIO $ signRS256 header claims rsaSK of
          Left err   -> error $ "Unable to sign UCAN: " <> show err
          Right ucan -> ucan

      Right edSK ->
        signEd25519 header claims edSK

instance
  ( ToJSON fct
  , ToJSON cap
  ) => ToJSON (UCAN fct cap) where
  toJSON UCAN {..} = String $ content <> "." <> textDisplay sig
    where
      content = decodeUtf8Lenient $ encodeB64 header <> "." <> encodeB64 claims

      encodeB64 jsonable =
        jsonable
          & encode
          & Lazy.toStrict
          & UTF8.stripQuotesBS
          & BS.B64.URL.encodeBase64'
          & UTF8.stripPadding

instance
  ( FromJSON fct
  , FromJSON cap
  ) => FromJSON (UCAN fct cap) where
  parseJSON = parseUcanV_0_3

instance
  ( ToJSON fct
  , ToJSON cap
  ) => Servant.ToHttpApiData (UCAN fct cap) where
  toUrlPiece ucan =
    ucan
      & encode
      & Lazy.toStrict
      & decodeUtf8Lenient
      & UTF8.stripQuotes

------------
-- Claims --
------------

data Claims fct cap = Claims
  -- Dramatis Personae
  { sender      :: DID
  , receiver    :: DID
  -- Authorization Target
  , attenuation :: [cap]
  , proofs      :: [EncodedProof]
  -- 0.3.1
  , facts       :: [fct]
  -- Temporal Bounds
  , exp         :: UTCTime
  , nbf         :: UTCTime
  , nnc         :: Maybe Nonce
  } deriving (Show, Functor)

instance (Show fct, Show cap) => Display (Claims fct cap) where
  textDisplay = Text.pack . show

instance (Eq fct, Eq cap) => Eq (Claims fct cap) where
  jwtA == jwtB = eqWho && eqAuth && eqTime && eqFacts && eqNonce
    where
      eqWho = sender jwtA == sender   jwtB
         && receiver jwtA == receiver jwtB

      eqAuth = attenuation jwtA == attenuation jwtB
             &&     proofs jwtA == proofs      jwtB

      eqTime = roundUTC (exp jwtA) == roundUTC (exp jwtB)
            && roundUTC (nbf jwtA) == roundUTC (nbf jwtB)

      eqFacts = facts jwtA == facts jwtB

      eqNonce = nnc jwtA == nnc jwtB

instance
  ( Arbitrary fct
  , Arbitrary cap
  , ToJSON fct
  , ToJSON cap
  ) => Arbitrary (Claims fct cap) where
  arbitrary = do
    sender      <- arbitrary
    receiver    <- DID.Key <$> arbitrary
    attenuation <- arbitrary
    proofs      <- map (Nested . textDisplay) <$> arbitraryProofs
    facts       <- arbitrary
    exp         <- arbitrary
    nbf         <- arbitrary
    nnc         <- arbitrary

    return Claims {..}
    where
      arbitraryProofs :: Gen [UCAN fct cap]
      arbitraryProofs =
        -- try to generate deep rather than wide UCANs
        frequency
          [ (1,  replicateM 2 arbitrary)
          , (4,  replicateM 1 arbitrary)
          , (20, replicateM 0 arbitrary)
          ]

instance
  ( ToJSON fct
  , ToJSON cap
  ) => ToJSON (Claims fct cap) where
  toJSON Claims {..} = object
    [ "iss" .= sender
    , "aud" .= receiver
    --
    , "prf" .= proofs
    , "att" .= attenuation
    , "fct" .= facts
    --
    , "nbf" .= toSeconds nbf
    , "exp" .= toSeconds exp
    , "nnc" .= nnc
    ]

instance
  ( FromJSON fct
  , FromJSON cap
  ) => FromJSON (Claims fct cap) where
  parseJSON = parseClaimsV_0_3


-----------
-- Proof --
-----------

data EncodedProof
  = Nested    Text
  | Reference CID
  deriving (Show, Eq)


instance Display EncodedProof where
  display = \case
    Nested raw    -> "Nested "    <> display raw
    Reference cid -> "Reference " <> display cid

instance ToJSON EncodedProof where
  toJSON = \case
    Reference cid ->
      toJSON cid

    Nested raw ->
      String raw

instance FromJSON EncodedProof where
  parseJSON val =
    val
      & withText "Credential Proof" \txt ->
        if "eyJ" `Text.isPrefixOf` txt -- i.e. starts with Base64 encoded '{'
          then pure $ Nested txt
          else Reference <$> parseJSON val


-----------
-- Nonce --
-----------

newtype Nonce = Nonce { unNonce :: Text }
  deriving (Eq, Show, Ord)

instance Arbitrary Nonce where
  arbitrary = Nonce . Text.pack <$> replicateM 6 (elements chars)
    where
      chars =
        ['A'..'Z']
        <> ['a'..'z']
        <> ['0'..'9']

instance FromJSON Nonce where
  parseJSON = withText "UCAN Nonce" (pure . Nonce)

instance ToJSON Nonce where
  toJSON = String . unNonce



-----------------------
-- Signature Helpers --
-----------------------


signEd25519 ::
  ( ToJSON fct
  , ToJSON cap
  )
  => Header
  -> Claims fct cap
  -> Ed25519.SecretKey
  -> UCAN fct cap
signEd25519 header claims sk = UCAN{..}
  where
    raw        = B64.URL.encodeJWT header claims
    signedData = RawContent raw
    sig        = Signature.Ed25519 $ Key.signWith sk $ encodeUtf8 raw

signRS256 ::
  ( MonadRandom m
  , ToJSON fct
  , ToJSON cap
  )
  => Header
  -> Claims fct cap
  -> RSA.PrivateKey
  -> m (Either RSA.Error (UCAN fct cap))
signRS256 header claims sk = do
  let raw = B64.URL.encodeJWT header claims
      signedData = RawContent raw
  sigResult <- RSA.PKCS15.signSafer (Just SHA256) sk (encodeUtf8 raw)
  case sigResult of
    Left err -> return $ Left err
    Right s  ->
      let sig = Signature.RS256 $ RS256.Signature s
      in return $ Right UCAN {..}


-----------------------------
-- Backwards-compatibility --
-----------------------------

parseClaimsV_0_3 ::
  ( FromJSON fct
  , FromJSON cap
  ) => Value -> JSON.Parser (Claims fct cap)
parseClaimsV_0_3 = withObject "JWT.Payload" \obj -> do
  sender   <- obj .: "iss"
  receiver <- obj .: "aud"
  --
  resource <- obj .:  "rsc" .!= Nothing
  potency  <- obj .:  "ptc" .!= Nothing
  proof    <- obj .:  "prf" .!= Nothing
  facts    <- obj .:? "fct" .!= []
  --
  nbf <- fromSeconds <$> obj .: "nbf"
  exp <- fromSeconds <$> obj .: "exp"

  attenuation <- case (resource, potency) of
    (Just rsc, Just pot) -> do
      capability <- parseJSON $ JSON.object
        [ ("rsc", rsc)
        , ("cap", pot)
        ]
      pure [capability]

    _ ->
      pure []

  return Claims
    { sender = sender
    , receiver = receiver
    , attenuation = attenuation
    , proofs = maybeToList proof
    , facts = facts
    , nbf = nbf
    , exp = exp
    , nnc = Nothing
    }


parseUcanV_0_3 ::
  ( FromJSON fct
  , FromJSON cap
  ) => Value -> JSON.Parser (UCAN fct cap)
parseUcanV_0_3 = withText "UCAN.Token" \txt ->
  case Text.split (== '.') txt of
    [rawHeader, rawClaims, rawSig] -> do
      header <- withEmbeddedJSON "Header" parseJSON $ jsonify rawHeader
      claims <- withEmbeddedJSON "Claims" parseClaimsV_0_3 $ jsonify rawClaims
      let
        raw = rawHeader <> "." <> rawClaims
        signedData = RawContent raw
      sig    <- Signature.parse (alg header) (toJSON rawSig)
      return UCAN {..}

    _ ->
      fail $ "Wrong number of JWT segments in:  " <> Text.unpack txt
  where
    jsonify = toJSON . Text.B64.URL.decodeBase64Lenient
