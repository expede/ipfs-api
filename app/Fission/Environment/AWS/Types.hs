-- | App configuration for AWS
module Fission.Environment.AWS.Types (Environment (..)) where

import qualified Network.AWS.Auth  as AWS

import           Fission.Prelude
import qualified Fission.AWS.Types as AWS
import qualified Fission.URL.Types as URL

data Environment = Environment
  { accessKey   :: !AWS.AccessKey  -- ^ Access Key
  , secretKey   :: !AWS.SecretKey  -- ^ Secret Key
  , zoneID      :: !AWS.ZoneID     -- ^ Hosted Zone
  , domainName  :: !URL.DomainName -- ^ Domain Name
  , route53MockEnabled :: !AWS.Route53MockEnabled
  }

instance Show Environment where
  show Environment {..} = intercalate "\n"
    [ "Environment {"
    , "  accessKey          = HIDDEN"
    , "  secretKey          = HIDDEN"
    , "  zoneId             = " <> show zoneID
    , "  domainName         = " <> show domainName
    , "  route53MockEnabled = " <> show route53MockEnabled
    , "}"
    ]

instance FromJSON Environment where
  parseJSON = withObject "AWS.Environment" \obj -> do
    accessKey          <- obj .: "access_key"
    secretKey          <- obj .: "secret_key"
    zoneID             <- obj .: "zone_id"
    domainName         <- obj .: "domain_name"
    route53MockEnabled <- obj .:? "route53_mock_enabled" .!= AWS.Route53MockEnabled False

    return <| Environment {..}
