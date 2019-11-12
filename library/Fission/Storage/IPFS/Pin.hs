module Fission.Storage.IPFS.Pin
  ( add
  , rm
  ) where

import qualified Network.HTTP.Client as HTTP

import           Fission.Prelude
import qualified Fission.Internal.UTF8       as UTF8

import qualified Fission.IPFS.Client.Pin     as Pin
import           Fission.IPFS.Error          as IPFS.Error
import           Fission.IPFS.Types          as IPFS
import qualified Fission.IPFS.Client         as IPFS.Client

add
  :: ( MonadRIO          cfg m
     , HasLogFunc        cfg
     , Has HTTP.Manager  cfg
     , Has IPFS.URL      cfg
     )
  => IPFS.CID
  -> m (Either IPFS.Error.Add CID)
add (CID hash) = IPFS.Client.run (IPFS.Client.pin hash) >>= \case
  Right Pin.Response { cids } ->
    case cids of
      [cid] -> do
        logDebug <| "Pinned CID " <> display hash
        return <| Right cid

      _ ->
        logLeft <| UnexpectedOutput <| UTF8.textShow cids

  Left err ->
    logLeft err

-- | Unpin a CID
rm
  :: ( MonadRIO          cfg m
     , Has HTTP.Manager  cfg
     , Has IPFS.URL      cfg
     , HasLogFunc        cfg
     )
  => IPFS.CID
  -> m (Either IPFS.Error.Add CID)
rm cid@(CID hash) = IPFS.Client.run (IPFS.Client.unpin hash False) >>= \case
  Right Pin.Response { cids } ->
    case cids of
      [cid'] -> do
        logDebug <| "Pinned CID " <> display hash
        return <| Right cid'

      _ ->
        logLeft <| UnexpectedOutput <| UTF8.textShow cids

  Left _ -> do
    logDebug <| "Cannot unpin CID " <> display hash <> " because it was not pinned"
    return <| Right cid

logLeft :: (MonadRIO cfg m, HasLogFunc cfg, Show a) => a -> m (Either IPFS.Error.Add b)
logLeft errStr = do
  let err = UnknownAddErr <| UTF8.textShow errStr
  logError <| display err
  return <| Left err
