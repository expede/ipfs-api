module Fission.Web.User
  ( API
  , Auth
  , RegisterRoute
  , VerifyRoute
  , UpdateDIDRoute
  , ResetRoute
  , EmailRoute
  , server
  ) where

import           Servant

import           Fission.Prelude
import           Fission.IPFS.DNSLink.Class as DNSLink

import qualified Fission.User as User

import qualified Fission.Web.User.Create          as Create
import qualified Fission.Web.User.Verify          as Verify
import qualified Fission.Web.User.Email           as Email
import qualified Fission.Web.User.Password.Reset  as Reset
import qualified Fission.Web.User.UpdateDID       as UpdateDID

import qualified Fission.Web.Auth.Types           as Auth

type API = RegisterRoute
      :<|> VerifyRoute
      :<|> UpdateDIDRoute
      :<|> EmailRoute
      :<|> ResetRoute

type Auth = Auth.HigherOrder

type RegisterRoute = Auth.RegisterDid
                    :> Create.API

type VerifyRoute = "verify"
                   :> Auth
                   :> Verify.API

type UpdateDIDRoute = "update_did"
                    :> Auth
                    :> UpdateDID.API

type ResetRoute = "reset_password"
                  :> Auth
                  :> Reset.API

type EmailRoute = "email"
                   :> Email.API

server ::
  ( MonadDNSLink     m
  , MonadLogger      m
  , MonadTime        m
  , MonadDB        t m
  , User.Creator   t
  , User.Retriever t
  , User.Modifier  t
  )
  => ServerT API m
server = Create.server
    :<|> Verify.server
    :<|> UpdateDID.server
    :<|> Email.server
    :<|> Reset.server
