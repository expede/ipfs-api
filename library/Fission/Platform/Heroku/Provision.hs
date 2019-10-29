module Fission.Platform.Heroku.Provision
  ( Request (..)
  , callbackUrl
  , name
  -- , oauthGrant
  , plan
  , region
  , uuid
  , Provision (..)
  , id
  , config
  , peers
  , message
  ) where

import RIO hiding (id)

import qualified Servant.Client as Client

import Control.Lens (makeLenses, (?~), (.~))
import Data.Maybe
import Data.Aeson
import Data.UUID as UUID
import Data.Swagger hiding (name)
import Database.Selda

import qualified Fission.Plan.Types                 as Plan
import qualified Fission.Platform.Heroku.Types      as Heroku
import qualified Fission.User.Provision.Types       as User
import           Fission.Security.Types
import           Fission.User                       (User)
import           Fission.IPFS.Types                 as IPFS
import           Fission.IPFS.Peer (fission)

data Request = Request
  { _callbackUrl :: Text          -- ^ The URL which should be used to retrieve updated information about the add-on and the app which owns it.
  , _name        :: Text          -- ^ Logical name of the resource being provisioned.
  -- , _oauthGrant :: Maybe Text -- OAuthGrant -- ^ OAuth object details (nullable).
  , _plan        :: Plan.Tier     -- ^ Name of the plan to provision (e.g. `basic`).
  , _region      :: Heroku.Region -- ^ Physical hosting region of the requesting client.
  , _uuid        :: UUID          -- ^ The unique identifier Heroku uses for the installed add-on. It corresponds with the id field in the Heroku Platform API.
  } deriving ( Eq
             , Show
             )

makeLenses ''Request

instance ToJSON Request where
  toJSON Request {..} = object
    [ "callback_url" .= _callbackUrl
    , "name"   .= _name
    , "plan"   .= _plan
    , "region" .= _region
    , "uuid"   .= _uuid
    ]

instance FromJSON Request where
  parseJSON = withObject "Heroku.Request" \obj -> do
    _callbackUrl <- obj .: "callback_url"
    _name        <- obj .: "name"
    _plan        <- obj .: "plan"
    _region      <- obj .: "region"
    _uuid        <- obj .: "uuid"
    return Request {..}

instance ToSchema Request where
  declareNamedSchema _ = do
    planSchema   <- declareSchemaRef $ Proxy @Plan.Tier
    regionSchema <- declareSchemaRef $ Proxy @Heroku.Region
    stringSchema <- declareSchemaRef $ Proxy @String
    uuidSchema   <- declareSchemaRef $ Proxy @UUID
    return $ NamedSchema (Just "ProvisionRequest") $ mempty
      & type_       ?~ SwaggerObject
      & title       ?~ "Heroku Provisioning Request"
      & description ?~ "Request from Heroku to provision a new user"
      & properties  .~ [ ("callbackUrl", stringSchema)
                       , ("name",        stringSchema)
                       , ("plan",        planSchema)
                       , ("region",      regionSchema)
                       , ("uuid",        uuidSchema)
                       ]
      & required    .~ [ "callbackUrl"
                       , "name"
                       , "plan"
                       , "region"
                       , "uuid"
                       ]
      & example     ?~ toJSON Request
                         { _callbackUrl = "callback.herokuapp.com/foo"
                         , _name        = "my-awesome-app"
                         , _plan        = Plan.Free
                         , _region      = Heroku.Tokyo
                         , _uuid        = fromJust $ UUID.fromString "0cebfcfe-93c9-11e9-bc42-526af7764f64"
                         }

{-| Response Parameters

From Heroku

> In addition to the id parameter as documented under asynchronous provisioning,
> you should include a config parameter along with any other optional parameters
> of your choosing.
>
> Name: config
> Type: object
>
> Description:
> Configuration variables to be set as environment variables on any applications
> that use this add-on resource. All environment variables that you send should
> have the same prefix: your add-on’s name, capitalized. However,
> within the context of a Heroku app, the prefix may be different for a variety
> of reasons. For example, if your add-on is named fast-db and you are setting
> FAST_DB_URL, the variable name on the application will default to FAST_DB_URL
> but would be PRIMARY_DB_URL if the user added the add-on with
> the prefix PRIMARY_DB.
>
> Example:
> HTTP/1.1 200 OK
> { "MYADDON_URL": "http://myaddon.com/52e82f5d73" }
-}

data Provision = Provision
  { _id      :: ID User           -- ^ User ID
  , _config  :: User.Provision    -- ^ Heroku env var payload
  , _peers   :: [IPFS.Peer]       -- ^ IPFS peer list
  , _message :: Text              -- ^ A helpful human-readable message
  } deriving ( Eq
             , Show
             )

makeLenses ''Provision

instance ToJSON Provision where
  toJSON Provision {..} = object
    [ "id"      .= _id
    , "config"  .= _config
    , "message" .= _message
    ]

instance ToSchema Provision where
  declareNamedSchema _ = do
    uId       <- declareSchemaRef $ Proxy @(ID User)
    usrCfg    <- declareSchemaRef $ Proxy @User.Provision
    ipfsPeers <- declareSchemaRef $ Proxy @[IPFS.Peer]
    txt       <- declareSchemaRef $ Proxy @Text
    return $ NamedSchema (Just "User Provision Response") $ mempty
           & type_      ?~ SwaggerObject
           & properties .~
               [ ("id",      uId)
               , ("config",  usrCfg)
               , ("message", txt)
               , ("peers", ipfsPeers)
               ]
           & required    .~ ["id" , "config"]
           & example     ?~ toJSON provisionEx
           & description ?~ "Provisioned user login information"
    where
      provisionEx = Provision
        { _id      = toId 4213
        , _config  = cfgEx
        , _peers  = [fission]
        , _message = "Provisioned successfully"
        }

      cfgEx = User.Provision
        { _url      = Client.BaseUrl Client.Https "runfission.com" 443 ""
        , _username = "c74bd95b8555275277d4"
        , _password = Secret "GW0SHByPmY0.y+lg)x7De.PNmJvh1"
        }
