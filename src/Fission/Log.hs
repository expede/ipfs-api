{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Fission.Log where

import           RIO
import qualified RIO.ByteString as BS
import qualified RIO.Text       as Text

import Data.Has

import Fission.Internal.Constraint

newtype MinLogLevel = MinLogLevel LogLevel

atLevel :: MonadRIO cfg m
        => Has MinLogLevel cfg
        => CallStack -> LogSource -> LogLevel -> Utf8Builder -> m ()
atLevel cs src lvl msg = do
  MinLogLevel minLevel <- view hasLens
  if lvl >= minLevel
    then liftIO $ simple cs src lvl msg
    else return ()

simple :: MonadIO m => CallStack -> LogSource -> LogLevel -> Utf8Builder -> m ()
simple _ src lvl msg =
  BS.putStr . Text.encodeUtf8 $ mconcat
    [ "*** "
    , short lvl
    , " *** "
    , textDisplay src
    , " | "
    , textDisplay msg
    ]

short :: LogLevel -> Text
short = \case
  LevelDebug     -> "Warn"
  LevelError     -> "Error"
  LevelInfo      -> "Info"
  LevelOther lvl -> "Other: " <> lvl
  LevelWarn      -> "Warn"
