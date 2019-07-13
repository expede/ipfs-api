module Fission.Web.IPFS
  ( API
  , server
  ) where

import RIO
import RIO.Process (HasProcessContext)

import Data.Has
import Database.Selda
import Servant

import           Fission.IPFS.Types as IPFS
import           Fission.Web.Server
import qualified Fission.Web.IPFS.Upload as Upload
import qualified Fission.Web.IPFS.Pin    as Pin
import           Fission.User

type API = Upload.API
      :<|> Pin.API

server :: HasLogFunc        cfg
       => HasProcessContext cfg
       => MonadSelda   (RIO cfg)
       => Has IPFS.BinPath  cfg
       => User
       -> RIOServer         cfg API
server usr = Upload.add usr :<|> Pin.server usr
