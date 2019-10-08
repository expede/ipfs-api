module Fission.AWS.Route53 
  ( createChangeRequest
  , registerDomain
  ) where

import RIO

import Data.Has
import qualified Fission.Config as Config

import Network.AWS.Route53 as Route53
import Network.AWS.Prelude as AWS
import Network.AWS.Auth    as AWS
import Fission.AWS.Types   as AWS
import Control.Monad.Trans.AWS

import Fission.Internal.Constraint
import  Fission.IPFS.CID.Types


import Control.Lens ((?~))

registerDomain :: MonadRIO      cfg m
           => Has AWS.AccessKey cfg
           => Has AWS.SecretKey cfg
           => Has AWS.ZoneId    cfg
           => Has AWS.Domain    cfg
           => Text
           -> CID
           -> m(Bool)
registerDomain subdomain cid= do 
  env <- createEnv
  let dnslink = "dnslink=/ipfs/" <> (unaddress cid)
  baseReq <- createChangeRequest Cname subdomain "ipfs.runfission.com"
  dnslinkReq <- createChangeRequest Txt ("_dnslink." <> subdomain) $ wrapQuotes dnslink
  liftIO $ runResourceT . runAWST env . within NorthVirginia $ do
    _ <- send(baseReq)
    _ <- send(dnslinkReq)
    return True

createEnv :: MonadRIO           cfg m
           => Has AWS.AccessKey cfg
           => Has AWS.SecretKey cfg
           => m(Env)
createEnv = do
  AccessKey accessKey <- Config.get
  SecretKey secretKey <- Config.get
  liftIO $ newEnv $ FromKeys (AccessKey accessKey) (SecretKey secretKey)

createChangeRequest :: MonadRIO       cfg m
                    => Has AWS.ZoneId cfg
                    => Has AWS.Domain cfg
                    => RecordType
                    -> Text
                    -> Text
                    -> m(ChangeResourceRecordSets)
createChangeRequest recordType subdomain content = do
  Domain domain <- Config.get
  ZoneId zoneId <- Config.get
  let
    recordSet = resourceRecordSet (subdomain <> domain) recordType
    updated = addValue recordSet content
    changes = changeBatch $ toNonEmpty [change Upsert updated]
    zone = ResourceId zoneId
  return $ changeResourceRecordSets zone changes

addValue :: ResourceRecordSet -> Text -> ResourceRecordSet
addValue recordSet value = do
  let record = resourceRecord value
  (recordSet & rrsResourceRecords ?~ toNonEmpty [record]) & rrsTTL ?~ (300 ::Natural)

wrapQuotes :: Text -> Text
wrapQuotes txt = "\"" <> txt <> "\""
