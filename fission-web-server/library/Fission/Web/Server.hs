-- | Top level web application and API
module Fission.Web.Server
  ( API
  , app
  , server
  , runServer
  ) where

import           Network.IPFS
import           Network.IPFS.Client.Streaming.Pin
import           Servant

import           Fission.Prelude

import qualified Fission.Web.API.Host.Types                  as Web
import qualified Fission.Web.API.Types                       as Fission

import qualified Fission.Web.Auth.Token.JWT.Resolver         as Proof

import qualified Fission.Web.Server.Auth                     as Auth
import qualified Fission.Web.Server.Challenge                as Challenge
import           Fission.Web.Server.Email
import qualified Fission.Web.Server.RecoveryChallenge        as RecoveryChallenge
import qualified Fission.Web.Server.Swagger                  as Web.Swagger
import qualified Fission.Web.Server.User                     as User
import           Fission.Web.Server.WNFS

import qualified Fission.Web.Server.Handler.App              as App
import qualified Fission.Web.Server.Handler.DNS              as DNS
import qualified Fission.Web.Server.Handler.Heroku           as Heroku
import qualified Fission.Web.Server.Handler.IPFS             as IPFS
import qualified Fission.Web.Server.Handler.Ping             as Ping
import qualified Fission.Web.Server.Handler.User             as User
import qualified Fission.Web.Server.Heroku.AddOn             as Heroku.AddOn
import qualified Fission.Web.Server.Swagger.Types            as Swagger

import           Fission.Web.Server.IPFS.DNSLink             as DNSLink
import qualified Fission.Web.Server.LoosePin                 as LoosePin

import qualified Fission.Web.Server.App                      as App
import qualified Fission.Web.Server.App.Content              as App.Content
import qualified Fission.Web.Server.App.Domain               as App.Domain

import qualified Fission.Web.Server.Handler.Auth.UCAN.Verify as Auth.UCAN.Verify

import           Fission.Web.Server.Types                    as Fission

import           Fission.Web.Server.Handler
import qualified Fission.Web.Server.Handler.Relay            as Relay
import           Fission.Web.Server.Handler.Relay.Types

import           Fission.Web.Server.IPFS.Cluster             as Cluster
import           Fission.Web.Server.IPFS.Linked
import           Fission.Web.Server.MonadDB
import           Fission.Web.Server.Reflective
import           Fission.Web.Server.Relay.Store.Class

import           Fission.Internal.Orphanage.OctetStream      ()
import           Fission.Internal.Orphanage.PlainText        ()

import qualified Paths_fission_web_server                    as Fission

-- | Top level web API type. Handled by 'server'.
type API
  -- V2
  =    Swagger.V2
  :<|> Fission.V2
  -- Unversioned
  :<|> Swagger.V_
  :<|> Fission.V_
  :<|> LinkWS
  :<|> Root

type Root   = Get '[JSON, OctetStream, PlainText] NoContent
type LinkWS = "user" :> "link" :> RelayWS

app ::
  ( App.Domain.Initializer      m
  , App.Content.Initializer     m
  , App.CRUD                    m
  , Proof.Resolver              m
  , MonadReflectiveServer       m
  , MonadRelayStore             m
  , MonadLinkedIPFS             m
  , MonadIPFSCluster            m PinStatus
  , MonadRemoteIPFS             m
  , MonadDNSLink                m
  , MonadWNFS                   m
  , MonadLogger                 m
  , MonadTime                   m
  , MonadEmail                  m
  , User.CRUD                   m
  , Challenge.Creator           m
  , Challenge.Retriever         m
  , Challenge.Verifier          m
  , RecoveryChallenge.Creator   m
  , RecoveryChallenge.Retriever m
  , RecoveryChallenge.Destroyer m
  , MonadDB                   t m
  , MonadLogger               t
  , MonadThrow                t
  , Heroku.AddOn.CRUD         t
  , LoosePin.CRUD             t
  , User.Retriever            t
  , User.Destroyer            t
  , App.Retriever             t
  , App.Domain.Retriever      t
  )
  => (forall a . m a -> Handler a)
  -> Context Auth.Checks
  -> Web.Host
  -> Application
app handlerNT authChecks appHost = do
  appHost
    |> server
    |> Auth.authWithContext api handlerNT
    |> serveWithContext     api authChecks
  where
    api = Proxy @API

-- | Web handlers for the 'API'
server ::
  ( App.Domain.Initializer      m
  , App.Content.Initializer     m
  , App.CRUD                    m
  , Proof.Resolver              m
  , MonadReflectiveServer       m
  , MonadRelayStore             m
  , MonadLinkedIPFS             m
  , MonadRemoteIPFS             m
  , MonadIPFSCluster            m PinStatus
  , MonadDNSLink                m
  , MonadWNFS                   m
  , MonadLogger                 m
  , MonadTime                   m
  , MonadEmail                  m
  , User.CRUD                   m
  , Challenge.Creator           m
  , Challenge.Retriever         m
  , Challenge.Verifier          m
  , RecoveryChallenge.Creator   m
  , RecoveryChallenge.Retriever m
  , RecoveryChallenge.Destroyer m
  , MonadDB                   t m
  , MonadLogger               t
  , MonadThrow                t
  , Heroku.AddOn.CRUD         t
  , LoosePin.CRUD             t
  , User.Retriever            t
  , User.Destroyer            t
  , App.Retriever             t
  , App.Domain.Retriever      t
  )
  => Web.Host
  -> ServerT API m
server appHost
  =    Web.Swagger.handler fromHandler appHost Fission.version (Proxy @Fission.V2)
  :<|> v2
  :<|> Web.Swagger.handler fromHandler appHost Fission.version (Proxy @Fission.V_)
  :<|> v_
  :<|> Relay.relay
  :<|> pure NoContent
  where
    v2 = v_
    v_ =   IPFS.handler
      :<|> App.handler
      :<|> Heroku.handler
      :<|> User.handler
      :<|> Ping.handler
      :<|> DNS.handler
      :<|> Auth.UCAN.Verify.handler
