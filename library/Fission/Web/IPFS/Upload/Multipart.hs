module Fission.Web.IPFS.Upload.Multipart
  ( API
  , FileRequest
  , NameQuery
  , add
  , jsonAdd
  , textAdd
  ) where

import           Database.Esqueleto
import qualified RIO.Text as Text

import           Network.IPFS
import qualified Network.IPFS.SparseTree  as IPFS
import qualified Network.IPFS.Types       as IPFS
import qualified Network.IPFS.Add         as IPFS
import qualified Network.IPFS.Pin         as IPFS.Pin

import           Servant
import           Servant.Multipart

import           Fission.Models
import           Fission.Prelude
import           Fission.Internal.MIME

import           Fission.User.CID  as User.CID
import qualified Fission.Web.Error as Web.Err

type API = TextAPI :<|> JSONAPI

type TextAPI = FileRequest
               :> NameQuery
               :> Post '[OctetStream, PlainText] IPFS.Path

type JSONAPI = FileRequest
               :> NameQuery
               :> Post '[JSON] IPFS.SparseTree

type FileRequest = MultipartForm Mem (MultipartData Mem)
type NameQuery   = QueryParam "name" IPFS.Name

add ::
  ( MonadRemoteIPFS    m
  , MonadLocalIPFS     m
  , MonadLogger        m
  , MonadThrow         m
  , MonadTime          m
  , MonadDB          t m
  , User.CID.Creator t
  )
  => Entity User
  -> ServerT API m
add (Entity userId _) = textAdd userId :<|> jsonAdd userId

textAdd ::
  ( MonadRemoteIPFS    m
  , MonadLocalIPFS     m
  , MonadLogger        m
  , MonadThrow         m
  , MonadTime          m
  , MonadDB          t m
  , User.CID.Creator t
  )
  => UserId
  -> ServerT TextAPI m
textAdd uID form queryName = run uID form queryName <| \sparse ->
  case IPFS.linearize sparse of
    Right hash -> pure hash
    Left err   -> Web.Err.throw err

jsonAdd ::
  ( MonadRemoteIPFS    m
  , MonadLocalIPFS     m
  , MonadLogger        m
  , MonadTime          m
  , MonadThrow         m
  , MonadDB          t m
  , User.CID.Creator t
  )
  => UserId
  -> ServerT JSONAPI m
jsonAdd uID form queryName = run uID form queryName pure

run ::
  ( MonadRemoteIPFS    m
  , MonadLocalIPFS     m
  , MonadLogger        m
  , MonadThrow         m
  , MonadTime          m
  , MonadDB          t m
  , User.CID.Creator t
  )
  => UserId
  -> MultipartData Mem
  -> Maybe IPFS.Name
  -> (IPFS.SparseTree -> m a)
  -> m a
run uID form qName cont = case lookupFile "file" form of
  Nothing -> throwM <| err422 { errBody = "File not processable by IPFS" }
  Just FileData { .. } ->
    IPFS.addFile fdPayload humanName >>= \case
      Left err ->
        Web.Err.throw err

      Right (struct, rootCID) -> IPFS.Pin.add rootCID >>= \case
        Left err ->
          Web.Err.throw err

        Right _ -> do
          struct
            |> IPFS.cIDs
            |> User.CID.createX uID
            |> runDBNow
            |> void

          cont struct
    where
      humanName :: IPFS.Name
      humanName = toName qName fdFileName fdFileCType

toName :: Maybe IPFS.Name -> Text -> Text -> IPFS.Name
toName queryName' fileName mime =
  case queryName' of
    Nothing              -> IPFS.Name <| plainName fileName mime
    Just (IPFS.Name "")  -> IPFS.Name <| plainName fileName mime
    Just ipfsName        -> ipfsName

plainName :: Text -> Text -> String
plainName ""       mime = Text.unpack <| "file." <> lookupExt (encodeUtf8 mime)
plainName fileName _    = Text.unpack fileName
