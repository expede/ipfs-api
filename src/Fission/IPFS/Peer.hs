{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}

module Fission.IPFS.Peer where

import           RIO
import qualified RIO.ByteString.Lazy as Lazy
import qualified RIO.Text            as Text

import Data.Aeson
import Data.Aeson.TH

import qualified Fission.Internal.UTF8 as UTF8
import qualified Fission.IPFS.Process  as IPFSProc

import Fission.Env
import Fission.Internal.Constraint

data Peer = Peer { peer :: Text }
$(deriveJSON defaultOptions ''Peer)

all :: (WithRIO env m, HasIPFSPath env) => m (Either UnicodeException [Peer])
all = do
  allRaw         <- getAllRaw
  textOrErr      <- return $ UTF8.encode allRaw
  peerNamesOrErr <- return $ Text.lines <$> textOrErr
  return $ (fmap Peer) <$> peerNamesOrErr

getAllRaw :: (WithRIO env m, HasIPFSPath env) => m Lazy.ByteString
getAllRaw = IPFSProc.run' ["bootstrap", "list"]
