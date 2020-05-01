module Fission.Key.Asymmetric.Public.Types (Public (..)) where

-- import           Crypto.Error
import qualified Crypto.PubKey.Ed25519 as Crypto.Ed25519
import qualified Crypto.PubKey.RSA     as Crypto.RSA
-- import qualified Crypto.Store.X509     as X509

-- import qualified Data.ASN1.BinaryEncoding as ASN1
-- import qualified Data.ASN1.Encoding       as ASN1
-- import qualified Data.ASN1.Types          as ASN1
 
-- import qualified Data.PEM as PEM

import           Data.Swagger
import           Database.Persist.Postgresql

-- import qualified Data.ByteString.Base64 as BS64
-- import qualified Data.X509              as X509

import qualified RIO.Text as Text 
import           Servant.API

import           Fission.Prelude hiding (length)

-- import           Fission.Internal.Base64.Scrubbed    as B64.Scrubbed
-- import qualified Fission.Internal.Base64             as B64
import           Fission.Internal.RSA2048.Pair.Types as Pair

import           Fission.Internal.Orphanage.RSA2048.Public    ()
import           Fission.Internal.Orphanage.Ed25519.PublicKey ()

data Public
  = Ed25519PublicKey Crypto.Ed25519.PublicKey
  | RSAPublicKey     Crypto.RSA.PublicKey
  deriving Eq

instance Show Public where
  show = Text.unpack . textDisplay

instance Display Public where
  textDisplay (Ed25519PublicKey pk) = textDisplay pk
  textDisplay (RSAPublicKey     pk) = textDisplay pk

instance Arbitrary Public where
  arbitrary = oneof
    [ Ed25519PublicKey       <$> arbitrary
    , RSAPublicKey . Pair.pk <$> arbitrary
    ]

instance ToHttpApiData Public where
  toUrlPiece = textDisplay

instance FromHttpApiData Public where
  parseUrlPiece txt =
    if | "MII" `Text.isPrefixOf` txt -> RSAPublicKey     <$> parseUrlPiece txt
       | Text.length txt == 61       -> Ed25519PublicKey <$> parseUrlPiece txt
       | otherwise -> Left $ "Unable to determine public key algorithm: " <> txt

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
      |> type_ ?~ SwaggerString
      |> description ?~ "A public key"
      |> NamedSchema (Just "PublicKey")
      |> pure
