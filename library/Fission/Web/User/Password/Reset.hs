module Fission.Web.User.Password.Reset
  ( API
  , server
  ) where

import           Database.Esqueleto
import           Servant

import           Fission.Models
import           Fission.Prelude
import           Fission.User.Mutation       as User
import qualified Fission.User.Password.Types as User
import qualified Fission.User.Password       as User.Password

import qualified Fission.Web.Error                     as Web.Err
import qualified Fission.Web.User.Password.Reset.Types as User.Password

type API = ReqBody '[JSON] User.Password.Reset
        :> Put     '[JSON] User.Password

server ::
  ( MonadIO     m
  , MonadDB     m
  , MonadTime   m
  , MonadThrow  m
  , MonadLogger m
  )
  => Entity User
  -> ServerT API m
server (Entity userId _) User.Password.Reset { maybePassword } = do
  password <- maybe User.Password.random pure maybePassword
  updated  <- User.updatePassword userId password

  case updated of
    Left  err         -> Web.Err.throw err
    Right updatedPass -> return updatedPass

  return password
