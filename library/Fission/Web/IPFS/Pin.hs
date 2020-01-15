module Fission.Web.IPFS.Pin
  ( API
  , PinAPI
  , UnpinAPI
  , server
  , pin
  , unpin
  ) where

import           Database.Esqueleto
import           Servant

import           Network.IPFS
import qualified Network.IPFS.Pin   as IPFS.Pin
import           Network.IPFS.CID.Types

import           Fission.Prelude
import qualified Fission.Web.Error as Web.Err
import qualified Fission.User.CID  as User.CID
import           Fission.Models

type API = PinAPI :<|> UnpinAPI

type PinAPI = Capture "cid" CID
           :> Put '[PlainText, OctetStream] NoContent

type UnpinAPI = Capture "cid" CID
             :> DeleteAccepted '[PlainText, OctetStream] NoContent

server ::
  ( MonadRemoteIPFS      m
  , MonadLogger          m
  , MonadThrow           m
  , MonadTime            m
  , MonadDB            t m
  , User.CID.Creator   t
  , User.CID.Retriever t
  , User.CID.Destroyer t
  )
  => Entity User
  -> ServerT API m
server (Entity userId _) = pin userId :<|> unpin userId

pin ::
  ( MonadRemoteIPFS    m
  , MonadLogger        m
  , MonadThrow         m
  , MonadTime          m
  , MonadDB          t m
  , User.CID.Creator t
  )
  => UserId
  -> ServerT PinAPI m
pin userId cid = IPFS.Pin.add cid >>= \case
  Left err -> Web.Err.throw err
  Right _  -> do
    cid
      |> User.CID.create userId
      |> runDBNow

    pure NoContent

unpin ::
  ( MonadRemoteIPFS      m
  , MonadLogger          m
  , MonadThrow           m
  , MonadDB            t m
  , User.CID.Retriever t
  , User.CID.Destroyer t
  )
  => UserId
  -> ServerT UnpinAPI m
unpin userId cid = do
  remaining <- runDB do
    User.CID.destroy userId cid
    User.CID.getByCids [cid]

  when (remaining == []) do
    void <| Web.Err.ensure =<< IPFS.Pin.rm cid

  return NoContent
