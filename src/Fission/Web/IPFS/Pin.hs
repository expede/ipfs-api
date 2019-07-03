module Fission.Web.IPFS.Pin
  ( API
  , put
  ) where

import RIO
import RIO.Process (HasProcessContext)

import Data.Has
import Servant

import qualified Fission.IPFS.Types   as IPFS
import qualified Fission.Storage.IPFS as Storage.IPFS
import qualified Fission.Web.Error    as Web.Err
import           Fission.Web.Server
import           Fission.IPFS.CID.Types

type API = Capture "cid" CID
           :> Put '[PlainText, OctetStream] NoContent

put :: Has IPFS.BinPath  cfg
    => HasProcessContext cfg
    => HasLogFunc        cfg
    => RIOServer         cfg API
put = either Web.Err.throw (pure . const NoContent) <=< Storage.IPFS.pin
