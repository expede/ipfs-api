module Fission.Web.IPFS.CID
  ( API
  , allForUser
  ) where

import RIO

import Database.Selda
import Servant

import qualified Fission.IPFS.Types     as IPFS
import           Fission.IPFS.CID.Types as IPFS.CID

import           Fission.User           (User (..))
import           Fission.User.CID.Query
import qualified Fission.User.CID.Table as Table

import           Fission.Web.Server

type API = Get '[JSON, PlainText] [CID]

allForUser :: MonadSelda (RIO cfg) => User -> RIOServer cfg API
allForUser User { _userID } = do
  hashes <- query do
    uCIDs <- select Table.userCIDs
    restrict $ uCIDs `byUser` _userID
    return $ uCIDs ! #_cid

  return $ IPFS.CID <$> hashes
