-- | Authorization types; primarily more semantic aliases
module Fission.Web.Auth.Token.Bearer.Types
  ( Token     (..)
  , BareToken (..)
  ) where

import qualified RIO.ByteString.Lazy                   as Lazy
import qualified RIO.Text                              as Text

import           Data.Aeson.Types
import           Servant.API

import           Fission.Prelude

import qualified Fission.Internal.Base64.URL           as B64.URL

import qualified Fission.Web.Auth.Token.JWT.RawContent as JWT
import           Fission.Web.Auth.Token.JWT.Types

data Token = Token
  { jwt        :: JWT            -- ^ The actual token
  , rawContent :: JWT.RawContent -- ^ Primarily to pass in to the verifier
  }
  deriving (Show, Eq)

instance Ord Token where
  a `compare` b = textDisplay a `compare` textDisplay b

instance Arbitrary Token where
  arbitrary = do
    jwt@JWT {..} <- arbitrary
    return Token
      { jwt
      , rawContent = RawContent $ B64.URL.encodeJWT header claims
      }

instance Display Token where
  textDisplay = Text.pack . show

instance ToJSON Token where
  toJSON Token {jwt = JWT {sig}, rawContent} =
    String $ "Bearer " <> textDisplay rawContent <> "." <> textDisplay sig

instance FromJSON Token where
  parseJSON = withText "Bearer Token" \txt ->
    case Text.stripPrefix "Bearer " txt <|> Text.stripPrefix "bearer " txt of
      Just rawToken -> do
        jwt <- parseJSON $ toJSON rawToken
        return Token { jwt, rawContent = JWT.contentOf rawToken }

      Nothing ->
        fail $ Text.unpack txt <> " is missing the `Bearer ` prefix"

instance ToHttpApiData Token where
  toUrlPiece token =
    Text.dropEnd 1 . Text.drop 1 . decodeUtf8Lenient . Lazy.toStrict $ encode token

instance FromHttpApiData Token where
  parseUrlPiece txt =
    case Text.stripPrefix "Bearer " txt <|> Text.stripPrefix "bearer " txt of
      Just rawToken ->
        case eitherDecodeStrict . encodeUtf8 $ "\"" <> rawToken <> "\"" of
          Left  str -> Left $ Text.pack str
          Right jwt -> Right Token { jwt, rawContent = JWT.contentOf rawToken }

      Nothing ->
        Left $ txt <> " is missing the `Bearer ` prefix"

--------------
-- newtypes --
--------------

-- | Same as 'Token', but serialized without the 'bearer'. Internal use for UCANs.
newtype BareToken = BareToken Token
  deriving (Eq, Show)

instance ToJSON BareToken where
  toJSON (BareToken Token {jwt = JWT {sig}, rawContent}) =
    String $ textDisplay rawContent <> "." <> textDisplay sig

instance FromJSON BareToken where
  parseJSON = withText "Bearer Token" \txt -> do
    jwt <- parseJSON $ toJSON txt
    return $ BareToken Token { jwt, rawContent = JWT.contentOf txt }
