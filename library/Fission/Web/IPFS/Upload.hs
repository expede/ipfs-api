module Fission.Web.IPFS.Upload
  ( API
  , add
  ) where

import           Database.Esqueleto
import           Network.IPFS
import           Servant

import           Fission.Models
import           Fission.Prelude

import qualified Fission.Web.IPFS.Upload.Multipart as Multipart
import qualified Fission.Web.IPFS.Upload.Simple    as Simple

type API = Simple.API :<|> Multipart.API

add ::
  ( MonadLocalIPFS  m
  , MonadRemoteIPFS m
  , MonadLogger     m
  , MonadThrow      m
  , MonadTime       m
  , MonadDB         m
  )
  => Entity User
  -> ServerT API m
add usr = Simple.add    usr
     :<|> Multipart.add usr
