module Crypto.Key.Asymmetric.Public.Types (Public (..)) where

import qualified Crypto.PubKey.Ed25519                            as Crypto.Ed25519
import qualified Crypto.PubKey.RSA                                as Crypto.RSA
import qualified Crypto.Secp256k1

import           Data.Swagger
import           Database.Persist.Sql

import           Control.Lens                                     ((?~))
import           Data.Aeson
import           RIO
import qualified RIO.Text                                         as Text
import           Servant.API
import           Test.QuickCheck

import           Web.UCAN.Internal.RSA2048.Pair.Types             as Pair

import           Web.UCAN.Internal.Orphanage.Ed25519.PublicKey    ()
import           Web.UCAN.Internal.Orphanage.RSA2048.Public       ()
import           Web.UCAN.Internal.Orphanage.Secp256k1.PublicKey  ()

data Public
  = Ed25519PublicKey   Crypto.Ed25519.PublicKey
  | RSAPublicKey       Crypto.RSA.PublicKey
  | Secp256k1PublicKey Crypto.Secp256k1.PubKeyXY
  deriving Eq

instance Show Public where
  show = \case
    Ed25519PublicKey   ed -> Text.unpack $ textDisplay ed
    RSAPublicKey       pk -> show pk
    Secp256k1PublicKey pk -> Text.unpack $ textDisplay pk

instance Display Public where
  textDisplay (Ed25519PublicKey   pk) = textDisplay pk
  textDisplay (RSAPublicKey       pk) = textDisplay pk
  textDisplay (Secp256k1PublicKey pk) = Text.pack $ show pk

instance Arbitrary Public where
  arbitrary = oneof
    [ Ed25519PublicKey <$> arbitrary
    , RSAPublicKey . Pair.pk <$> arbitrary
    , Secp256k1PublicKey <$> arbitrary
    ]

instance ToHttpApiData Public where
  toUrlPiece = textDisplay

instance FromHttpApiData Public where
  parseUrlPiece txt =
    if "MII" `Text.isPrefixOf` txt
      then RSAPublicKey     <$> parseUrlPiece txt
      else Ed25519PublicKey <$> parseUrlPiece txt

instance IsString (Either Text Public) where
  fromString = parseUrlPiece . Text.pack

instance FromJSON Public where
  parseJSON = withText "PublicKey" \txt ->
    case parseUrlPiece txt of
      Right pk -> return pk
      Left msg -> fail $ Text.unpack msg

instance ToJSON Public where
  toJSON = String . textDisplay

instance PersistField Public where
  toPersistValue =
    PersistText . textDisplay

  fromPersistValue (PersistText txt) =
    parseUrlPiece txt

  fromPersistValue other =
    Left $ "Invalid Persistent PK: " <> Text.pack (show other)

instance PersistFieldSql Public where
  sqlType _pxy = SqlString

instance ToSchema Public where
  declareNamedSchema _ =
    mempty
      & type_ ?~ SwaggerString
      & description ?~ "A public key"
      & NamedSchema (Just "PublicKey")
      & pure
