module Fission.Web.API.User.Password.Reset.Types (Reset) where

import qualified Fission.User.Password.Reset.Types as User.Password
import qualified Fission.User.Password.Types       as User

import           Fission.Web.API.Prelude

import qualified Fission.Web.API.Auth.Types        as Auth

type Reset = "reset_password" :> API

type API
  =  Summary "Reset password"
  :> Description "DEPRECATED ⛔ Reset password"
  --
  :> ReqBody '[JSON] User.Password.Reset
  --
  :> Auth.HigherOrder
  :> Put     '[JSON] User.Password
