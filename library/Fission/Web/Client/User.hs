module Fission.Web.Client.User
  ( register
  , verify
  , updateDID
  , whoami
  ) where

import           Servant hiding (addHeader)
import           Servant.Client

import           Fission.Prelude

import qualified Fission.User.Registration.Types as User
import qualified Fission.User.Username.Types     as User
import qualified Fission.User.DID.Types          as User

import           Fission.Web.Client
import qualified Fission.Web.User   as User
import           Fission.Web.Routes (UserPrefix)

register  :: User.Registration -> ClientM NoContent
register = registerClient <| Proxy @(UserPrefix :> User.RegisterRoute)

verify :: ClientM Bool
verify = sigClient' <| Proxy @(UserPrefix :> User.VerifyRoute)

whoami :: ClientM User.Username
whoami = sigClient' <| Proxy @(UserPrefix :> User.WhoAmIRoute)

updateDID :: BasicAuthData -> User.DID -> ClientM NoContent
updateDID = basicClient <| Proxy @(UserPrefix :> User.UpdateDIDRoute)
