module Fission.Internal.URL
  ( isURL
  , specials
  ) where

import RIO

import Data.Word8

import Fission.Internal.Bool (anyX)

isURL :: Word8 -> Bool
isURL w = anyX (isAlpha : isDigit : isSpecial) w
  where
    isSpecial = ((==) <$> specials)

specials :: [Word8]
specials =
    [ _asterisk
    , _comma
    , _dollar
    , _exclam
    , _hyphen
    , _parenleft
    , _parenright
    , _period
    , _plus
    , _underscore
    ]
