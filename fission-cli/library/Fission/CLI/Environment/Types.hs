module Fission.CLI.Environment.Types (Env (..)) where

import qualified Network.IPFS.Types          as IPFS

import           Fission.Prelude

import           Fission.User.DID.Types
import           Fission.User.Username.Types

-- | "Global" environment
data Env = Env
  -- IPFS
  { peers          :: ![IPFS.Peer]
  , ignored        :: ![Text] -- ^ Passing through verbatim for ipfsignore

  -- IDs
  , serverDID      :: !DID
  , signingKeyPath :: !FilePath
  , username       :: !Username

  -- Releases
  , updateChecked  :: !UTCTime
  }

instance ToJSON Env where
  toJSON Env {..} = object
    [ "peers"            .= peers
    , "ignore"           .= ignored
    , "server_did"       .= serverDID
    , "signing_key_path" .= signingKeyPath
    , "username"         .= username
    , "update_checked"   .= updateChecked
    ]

instance FromJSON Env where
  parseJSON = withObject "Env" \obj -> do
    peers          <- obj .:  "peers"
    ignored        <- obj .:? "ignored" .!= []
    serverDID      <- obj .:  "server_did"
    signingKeyPath <- obj .:  "signing_key_path"
    username       <- obj .:  "username"
    updateChecked  <- obj .:? "update_checked" .!= fromSeconds 0

    return Env {..}
