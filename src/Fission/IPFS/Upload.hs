{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Fission.IPFS.Upload where

import           RIO
import qualified RIO.ByteString.Lazy as Lazy
import qualified RIO.Text            as Text

import Data.Bifunctor as Bi
import Data.Has

import qualified Fission.Internal.UTF8 as UTF8
import qualified Fission.IPFS.Process  as IPFS.Proc

import Fission.Internal.Constraint
import Fission.Config

run :: (MonadRIO cfg m, Has IpfsPath cfg) => Text -> m (Either UnicodeException Text)
run = fmap (Bi.second $ Text.dropSuffix "\n")
    . fmap UTF8.encode
    . IPFS.Proc.run ["add", "-q"]
    . Lazy.fromStrict
    . encodeUtf8
