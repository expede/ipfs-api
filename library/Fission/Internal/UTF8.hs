-- | UTF8 text helpers
module Fission.Internal.UTF8
  ( Textable (..)
  , putText
  , putTextLn
  , showLazyBS
  , displayLazyBS
  , stripN
  , stripNBS
  , stripNewline
  , textToLazyBS
  , textShow
  , wrapIn
  ) where

import           Flow
import           RIO
import qualified RIO.ByteString      as Strict
import qualified RIO.ByteString.Lazy as Lazy
import qualified RIO.Text            as Text


-- Property testing
--
-- $setup
-- >>> :set -XOverloadedStrings
-- >>> import Test.QuickCheck
-- >>> import Test.QuickCheck.Instances ()
-- >>> import qualified Data.Text as Text
-- >>> import qualified RIO.ByteString.Lazy as Lazy

class Textable a where
  encode :: a -> Either UnicodeException Text

instance Textable ByteString where
  encode = decodeUtf8'

instance Textable Lazy.ByteString where
  encode = encode . Lazy.toStrict

showLazyBS :: Show a => a -> Lazy.ByteString
showLazyBS = textToLazyBS . textDisplay . displayShow

displayLazyBS :: Display a => a -> Lazy.ByteString
displayLazyBS = Lazy.fromStrict . encodeUtf8 . textDisplay

textToLazyBS :: Text -> Lazy.ByteString
textToLazyBS = Lazy.fromStrict . Text.encodeUtf8

{-| Strip one newline character from the end of a lazy `ByteString`.

    >>> stripNewline ";)\n"
    ";)"

    >>> stripNewline "<>\n\n"
    "<>\n"

    prop> stripNewline (Lazy.append bs "\n") == bs
    prop> stripNewline (Lazy.append bs "\n\n") == bs <> "\n"

-}
stripNewline :: Lazy.ByteString -> Lazy.ByteString
stripNewline bs =
  bs
    |> Lazy.stripSuffix "\n"
    |> fromMaybe bs

{-| Show text.

    >>> textShow 1
    "1"

-}
textShow :: Show a => a -> Text
textShow = textDisplay . displayShow

{-| Remove a number of characters from the beginning and the end of a lazy `ByteString`.

    >>> stripNBS 3 "aaabccc"
    "b"

    >>> stripNBS 0 "b"
    "b"

-}
stripNBS :: Natural -> Lazy.ByteString -> Lazy.ByteString
stripNBS n bs = bs
             |> Lazy.take ((Lazy.length bs) - i)
             |> Lazy.drop i
  where
    i :: Int64
    i = fromIntegral n

{-| Remove a number of characters from the beginning and the end of some text.

    >>> stripN 3 "aaabccc"
    "b"

    >>> stripN 0 "b"
    "b"

    prop> stripN n (Text.center (3 + fromIntegral n * 2) '_' "o.O") == "o.O"

-}
stripN :: Natural -> Text -> Text
stripN n = Text.dropEnd i . Text.drop i
  where
    i :: Int
    i = fromIntegral n

-- | Helper for printing 'Text' to a console
putText :: MonadIO m => Text -> m ()
putText = Strict.putStr . encodeUtf8

-- | Helper for printing 'Text' to a console with a newline at the end
putTextLn :: MonadIO m => Text -> m ()
putTextLn txt = putText <| txt <> "\n"

{-| Wrap text with some other piece of text.

    prop> Text.head (wrapIn "|" s) == '|'
    prop> Text.last (wrapIn "|" s) == '|'
    prop> Text.length (wrapIn "|" s) == (Text.length s) + 2

-}
wrapIn :: Text -> Text -> Text
wrapIn wrapper txt = wrapper <> txt <> wrapper
