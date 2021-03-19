-- | UTF8 text helpers
module Fission.Internal.UTF8
  ( Textable (..)
  , putText
  , putTextLn
  , displayLazyBS
  , toBase58Text
  , fromRawBytes
  , stripOptionalPrefix
  , stripOptionalPrefixBS
  , stripOptionalPrefixLazyBS
  , stripOptionalSuffix
  , stripOptionalSuffixBS
  , stripOptionalSuffixLazyBS
  , stripPadding
  , stripQuotes
  , stripQuotesBS
  , stripQuotesLazyBS
  , stripN
  , stripNBS
  , stripNewline
  , textShow
  , wrapIn
  , wrapInBS
  ) where

import           Data.Base58String.Bitcoin as BS58.BTC
import           Data.Binary               hiding (encode)

import           Flow

import           RIO
import qualified RIO.ByteString            as Strict
import qualified RIO.ByteString.Lazy       as Lazy
import qualified RIO.Text                  as Text

class Textable a where
  encode :: a -> Either UnicodeException Text

instance Textable ByteString where
  encode = decodeUtf8'

instance Textable Lazy.ByteString where
  encode = encode . Lazy.toStrict

displayLazyBS :: Display a => a -> Lazy.ByteString
displayLazyBS = Lazy.fromStrict . encodeUtf8 . textDisplay

fromRawBytes :: [Word8] -> Text
fromRawBytes = decodeUtf8Lenient . Strict.pack

-- | Convert any binary object to 'Text'
--
-- NOTE that base58 text does not concatenate without decoding to some base2 first
toBase58Text :: Strict.ByteString -> Text
toBase58Text = BS58.BTC.toText . BS58.BTC.fromBytes

stripOptionalPrefix :: Text -> Text -> Text
stripOptionalPrefix pfx txt = maybe txt id $ Text.stripPrefix pfx txt

stripOptionalSuffix :: Text -> Text -> Text
stripOptionalSuffix sfx txt = maybe txt id $ Text.stripSuffix sfx txt

stripOptionalPrefixBS :: Strict.ByteString -> Strict.ByteString -> Strict.ByteString
stripOptionalPrefixBS pfx bs = maybe bs id $ Strict.stripPrefix pfx bs

stripOptionalSuffixBS :: Strict.ByteString -> Strict.ByteString -> Strict.ByteString
stripOptionalSuffixBS sfx bs = maybe bs id $ Strict.stripSuffix sfx bs

stripOptionalPrefixLazyBS :: Lazy.ByteString -> Lazy.ByteString -> Lazy.ByteString
stripOptionalPrefixLazyBS pfx bs = maybe bs id $ Lazy.stripPrefix pfx bs

stripOptionalSuffixLazyBS :: Lazy.ByteString -> Lazy.ByteString -> Lazy.ByteString
stripOptionalSuffixLazyBS sfx bs = maybe bs id $ Lazy.stripSuffix sfx bs

stripPadding :: ByteString -> ByteString
stripPadding  =
    stripOptionalSuffixBS "=" -- per RFC7515
  . stripOptionalSuffixBS "=" -- incase they trail
  . stripOptionalSuffixBS "=" -- incase they trail

stripQuotes :: Text -> Text
stripQuotes = stripOptionalPrefix "\"" . stripOptionalSuffix "\""

stripQuotesBS :: ByteString -> ByteString
stripQuotesBS = stripOptionalPrefixBS "\"" . stripOptionalSuffixBS "\""

stripQuotesLazyBS :: Lazy.ByteString -> Lazy.ByteString
stripQuotesLazyBS = stripOptionalPrefixLazyBS "\"" . stripOptionalSuffixLazyBS "\""

-- | Strip one newline character from the end of a lazy `ByteString`.
stripNewline :: Lazy.ByteString -> Lazy.ByteString
stripNewline bs =
  bs
    |> Lazy.stripSuffix "\n"
    |> fromMaybe bs

-- | Show text.
textShow :: Show a => a -> Text
textShow = textDisplay . displayShow

-- | Remove a number of characters from the beginning and the end of a lazy `ByteString`.
stripNBS :: Natural -> Lazy.ByteString -> Lazy.ByteString
stripNBS n bs =
  bs
    |> Lazy.take ((Lazy.length bs) - i)
    |> Lazy.drop i
  where
    i :: Int64
    i = fromIntegral n

-- | Remove a number of characters from the beginning and the end of some text.
stripN :: Natural -> Text -> Text
stripN n = Text.dropEnd i . Text.drop i
  where
    i :: Int
    i = fromIntegral n

-- | Helper for printing 'Text' to a console
putText :: MonadIO m => Text -> m ()
putText = Strict.putStr . encodeUtf8

-- | Helper for printing Text' to a console with a newline at the end
putTextLn :: MonadIO m => Text -> m ()
putTextLn txt = putText $ txt <> "\n"

-- | Wrap text with some other piece of text.
wrapIn :: Text -> Text -> Text
wrapIn wrapper txt = wrapper <> txt <> wrapper

wrapInBS :: ByteString -> ByteString -> ByteString
wrapInBS wrapper bs = wrapper <> bs <> wrapper
