module Fission.Web.Heroku.Provision
  ( API
  , create
  ) where

import           Data.UUID as UUID
import qualified Data.Text as Text

import           Network.IPFS
import           Network.IPFS.Peer  (getExternalAddress)
import           Servant

import           Fission.Prelude

import qualified Fission.Web.Error                          as Web.Err
import qualified Fission.Web.Heroku.MIME.VendorJSONv3.Types as Heroku
import qualified Fission.Web.Types                          as Web
import           Fission.Web.Server.Reflective

import           Fission.Platform.Heroku.Provision.Types
import           Fission.Platform.Heroku.Provision.Request.Types

import qualified Fission.Random               as Random
import           Fission.Security.Types       (Secret (..))
import qualified Fission.User.Provision.Types as User
import qualified Fission.User.Mutation        as User


type API = ReqBody '[JSON]                Request
        :> Post    '[Heroku.VendorJSONv3] Provision

create ::
  ( MonadDB               m
  , MonadTime             m
  , MonadThrow            m
  , MonadLogger           m
  , MonadLocalIPFS        m
  , MonadReflectiveServer m
  )
  => ServerT API m
create Request {uuid, region} = do
  let username = Text.pack (UUID.toString uuid)
  secret <- Random.alphaNum 50

  User.createWithHeroku uuid region username secret >>= \case
    Left err ->
      Web.Err.throw err

    Right userID -> do
      Web.Host url' <- getHost
      ipfsPeers     <- getExternalAddress >>= \case
        Right peers' ->
          pure peers'

        Left err -> do
          logError <| textShow err
          return []

      return Provision
        { id      = userID
        , peers   = ipfsPeers
        , message = "Successfully provisioned Interplanetary Fission!"
        , config  = User.Provision
           { username = username
           , password = Secret secret
           , url      = url'
           }
        }
