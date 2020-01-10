module Fission.Web.IPFS
  ( API
  , Auth
  , AuthedAPI
  , PublicAPI
  , UnauthedAPI
  , authed
  , public
  , server
  ) where

import           Database.Esqueleto
import           Network.IPFS
import           Servant

import           Fission.IPFS.Linked
import           Fission.Models
import           Fission.Prelude

import qualified Fission.Web.IPFS.CID      as CID
import qualified Fission.Web.IPFS.Upload   as Upload
import qualified Fission.Web.IPFS.Download as Download
import qualified Fission.Web.IPFS.Pin      as Pin
import qualified Fission.Web.IPFS.DAG      as DAG
import qualified Fission.Web.IPFS.Peer     as Peer
import qualified Fission.User.CID as User.CID


type API = AuthedAPI
      :<|> PublicAPI

type Auth = BasicAuth "registered users" (Entity User)

type AuthedAPI = Auth :> UnauthedAPI

type UnauthedAPI = "cids" :> CID.API
              :<|> Upload.API
              :<|> Pin.API
              :<|> "dag" :> DAG.API

type PublicAPI = "peers" :> Peer.API
            :<|> Download.API

server ::
  ( User.CID.MonadDBMutation m
  , User.CID.MonadDBQuery    m
  , MonadDB                  m
  , MonadRemoteIPFS          m
  , MonadLinkedIPFS          m
  , MonadLocalIPFS           m
  , MonadLogger              m
  , MonadThrow               m
  , MonadTime                m
  )
  => ServerT API m
server = authed :<|> public

authed ::
  ( User.CID.MonadDBMutation m
  , User.CID.MonadDBQuery    m
  , MonadDB                  m
  , MonadRemoteIPFS          m
  , MonadLocalIPFS           m
  , MonadLogger              m
  , MonadThrow               m
  , MonadTime                m
  )
  => ServerT AuthedAPI m
authed usr = CID.allForUser usr
        :<|> Upload.add usr
        :<|> Pin.server usr
        :<|> DAG.put usr

public ::
  ( MonadLinkedIPFS m
  , MonadLocalIPFS  m
  , MonadLogger     m
  , MonadThrow      m
  )
  => ServerT PublicAPI m
public = Peer.get
    :<|> Download.get
