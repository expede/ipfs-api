module Fission.Web.Server.IPFS.Cluster.Client -- FIXME .Types
  ( API
  , PinAPI
  , StatusAPI
  ) where

-- 🌐

import qualified Network.IPFS.CID.Types                                  as IPFS
import           Servant

-- ⚛️

import qualified Fission.Web.Server.IPFS.Cluster.Pin.Global.Status.Types as Cluster

-- 🔺

type API = PinAPI :<|> StatusAPI

type PinAPI
  = "pins"
  :> Capture "cid" IPFS.CID
  :> PostNoContent

type StatusAPI
  = "pins"
  :> Capture "cid" IPFS.CID
  :> Get '[JSON] Cluster.GlobalPinStatus

-- ⚙️

-- pinClient    :: IPFS.CID -> ClientM NoContent
-- statusClient :: IPFS.CID -> ClientM Cluster.GlobalPinStatus
--
-- pinClient :<|> statusClient = client $ Proxy @API
