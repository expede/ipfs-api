{-# LANGUAGE MonoLocalBinds    #-}

module Fission.Web.Heroku
  ( API
  , create
  ) where

import RIO

import Data.Has
import Database.Selda
import Servant

import qualified Fission.Web.Heroku.MIME as Heroku.MIME
import           Fission.Web.Server

import qualified Fission.Platform.Heroku.UserConfig as Heroku
import           Fission.Platform.Heroku.Provision  as Provision

import           Fission
import           Fission.Security
import qualified Fission.Random                    as Random
import qualified Fission.User                      as User

import qualified Fission.Web.Types     as Web

--------------------------------------------------------------------------------

type API = "resources" :> CreateAPI

------------
-- CREATE --
------------

type CreateAPI = ReqBody '[JSON]                     Provision.Request
              :> Post    '[Heroku.MIME.VendorJSONv3] Provision

create :: HasLogFunc      cfg
       => Has Web.Host    cfg
       => MonadSelda (RIO cfg)
       => RIOServer       cfg API
create Request {_uuid, _region} = do
  Web.Host url <- fromConfig
  secret       <- liftIO $ Random.text 200
  userID       <- User.createFresh _uuid _region secret

  logInfo $ mconcat
    [ "Provisioned UUID: "
    , displayShow _uuid
    , " as "
    , displayShow userID
    ]

  let
    userConfig = Heroku.UserConfig
      { Heroku._interplanetaryFissionUrl      = url <> "/ipfs"
      , Heroku._interplanetaryFissionUsername = User.hashID userID
      , Heroku._interplanetaryFissionPassword = Secret secret
      }

  return Provision
    { _id      = userID
    , _config  = userConfig
    , _message = "Successfully provisioned Interplanetary FISSION!"
    }
