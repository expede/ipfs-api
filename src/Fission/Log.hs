module Fission.Log
  ( MinLevel (..)
  , atLevel
  , short
  , simple
  ) where

import           RIO
import           RIO.Char (toLower)
import qualified RIO.ByteString as BS
import qualified RIO.Text       as Text

import Data.Has
import System.Envy

import           Fission.Internal.Constraint
import qualified Fission.Internal.UTF8 as UTF8

newtype MinLevel = MinLevel LogLevel
  deriving (Eq, Show)

instance FromEnv MinLevel where
  fromEnv = do
    levelEnv <- env "MIN_LOG_LEVEL" .!= "debug"
    pure . MinLevel $ case fmap toLower levelEnv of
      "debug" -> LevelDebug
      "error" -> LevelError
      "info"  -> LevelInfo
      "warn"  -> LevelWarn
      other   -> LevelOther (UTF8.textShow (other :: String))

atLevel :: MonadRIO cfg m
        => Has MinLevel cfg
        => CallStack
        -> LogSource
        -> LogLevel
        -> Utf8Builder
        -> m ()
atLevel cs src lvl msg = do
  MinLevel minLevel <- view hasLens
  when (lvl >= minLevel) $
    liftIO $ simple cs src lvl msg

simple :: MonadIO m => CallStack -> LogSource -> LogLevel -> Utf8Builder -> m ()
simple _ src lvl msg =
  BS.putStr . Text.encodeUtf8 $ mconcat
    [ "*** "
    , short lvl
    , " *** "
    , textDisplay src
    , " | "
    , textDisplay msg
    , "\n"
    ]

short :: LogLevel -> Text
short = \case
  LevelDebug     -> "Debug"
  LevelError     -> "Error"
  LevelInfo      -> "Info"
  LevelWarn      -> "Warn"
  LevelOther lvl -> "Other: " <> lvl
