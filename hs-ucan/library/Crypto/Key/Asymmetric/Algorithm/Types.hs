-- | Cryptographic key algorithms

module Crypto.Key.Asymmetric.Algorithm.Types (Algorithm (..)) where

import           RIO
import qualified RIO.Text             as Text

import           Control.Lens         ((?~))
import           Data.Aeson
import           Test.QuickCheck

import           Data.Swagger
import           Database.Persist.Sql

-- | Cryptographic key algorithms (assymmetric)
data Algorithm
  = RSA2048
  | Ed25519
  | Secp256k1
  deriving (Eq, Show)

instance Arbitrary Algorithm where
  arbitrary = elements [RSA2048, Ed25519, Secp256k1]

instance ToJSON Algorithm where
  toJSON = String . \case
    RSA2048   -> "RS256" -- Per the JWT Spec (RFC 7519)
    Ed25519   -> "EdDSA"
    Secp256k1 -> "ES256K" -- Per COSE & JOSE Spec (RFC 8812)

instance FromJSON Algorithm where
  parseJSON = withText "JWT.Algorithm" \case
    "RS256"   -> return RSA2048
    "EdDSA"   -> return Ed25519
    "Ed25519" -> return Ed25519 -- NOTE historical, backwards compatibility
    "ES256K"  -> return Secp256k1
    other     -> fail (Text.unpack other <> " is not a valid JWT algorithm")

instance PersistField Algorithm where
  toPersistValue = \case
    RSA2048 -> PersistText "RSA2048"
    Ed25519 -> PersistText "Ed25519"
    Secp256k1 -> PersistText "Secp256k1"

  fromPersistValue = \case
    PersistText "RSA2048" -> Right RSA2048
    PersistText "Ed25519" -> Right Ed25519
    PersistText "Secp256k1" -> Right Secp256k1
    other -> Left ("Invalid Persistent public key algorithm: " <> Text.pack (show other))

instance ToSchema Algorithm where
  declareNamedSchema _ =
    mempty
      & type_ ?~ SwaggerString
      & NamedSchema (Just "PublicKeyAlgorithm")
      & pure

instance PersistFieldSql Algorithm where
  sqlType _pxy = SqlString
