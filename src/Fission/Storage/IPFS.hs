module Fission.Storage.IPFS
  ( addRaw
  , addFile
  , get
  , pin
  , unpin
  ) where

import           RIO
import qualified RIO.ByteString.Lazy as Lazy
import           RIO.Process (HasProcessContext)

import Data.Has
import Data.ByteString.Lazy.Char8 as CL

import qualified Network.HTTP.Client as HTTP

import qualified Fission.Config              as Config
import           Fission.Internal.Constraint
import           Fission.Internal.Orphanage ()
import           Fission.Internal.Process
import qualified Fission.File.Types          as File
import qualified Fission.Internal.UTF8       as UTF8
import qualified Fission.IPFS.Client.Pin     as Pin
import qualified Fission.IPFS.Process        as IPFS.Proc
import           Fission.IPFS.Error          as IPFS.Error
import           Fission.IPFS.Types          as IPFS
import qualified Fission.IPFS.Client         as IPFS.Client

get :: RIOProc           cfg m
    => Has IPFS.BinPath  cfg
    => Has IPFS.Timeout  cfg
    => IPFS.CID
    -> m (Either IPFS.Error.Get File.Serialized)
get cid@(IPFS.CID hash) = IPFS.Proc.run ["cat"] (UTF8.textToLazyBS hash) >>= \case
  (ExitSuccess, contents, _) ->
    return . Right $ File.Serialized contents

  (ExitFailure _, _, stdErr)
    | Lazy.isPrefixOf "Error: invalid 'ipfs ref' path" stdErr ->
        return . Left $ InvalidCID hash

    | Lazy.isSuffixOf "context deadline exceeded" stdErr -> do
        Timeout seconds <- Config.get
        return . Left $ TimedOut cid seconds

    | otherwise ->
        return . Left . UnknownGetErr $ UTF8.textShow stdErr

addRaw :: MonadRIO          cfg m
       => HasProcessContext cfg
       => HasLogFunc        cfg
       => Has HTTP.Manager  cfg
       => Has IPFS.URL      cfg
       => Has IPFS.BinPath  cfg
       => Has IPFS.Timeout  cfg
       => Lazy.ByteString
       -> m (Either IPFS.Error.Add IPFS.CID)
addRaw raw =
  IPFS.Proc.run ["add", "-q"] raw >>= \case
    (ExitSuccess, result, _) ->
      case CL.lines result of
        [cid] -> pin . mkCID . UTF8.stripN 1 $ UTF8.textShow cid
        bad   -> return . Left . UnexpectedOutput $ UTF8.textShow bad

    (ExitFailure _, _, err) ->
      return . Left . UnknownAddErr $ UTF8.textShow err

addFile :: MonadRIO          cfg m
        => HasProcessContext cfg
        => HasLogFunc        cfg
        => Has HTTP.Manager  cfg
        => Has IPFS.URL      cfg
        => Has IPFS.BinPath  cfg
        => Has IPFS.Timeout  cfg
        => Lazy.ByteString
        -> IPFS.Name
        -> m (Either IPFS.Error.Add IPFS.SparseTree)
addFile raw name =
  IPFS.Proc.run opts raw >>= \case
    (ExitSuccess, result, _) -> do
      pin (mkCID $ UTF8.textShow result) >>= \case
        Left err ->
          return . Left . UnknownAddErr $ UTF8.textShow err

        Right _ ->
          case CL.lines result of
            [inner, outer] ->
              let
                sparseTree  = Directory [(Hash rootCID, fileWrapper)]
                fileWrapper = Directory [(fileName, Content fileCID)]
                rootCID     = CID $ UTF8.textShow outer
                fileCID     = CID . UTF8.stripN 1 $ UTF8.textShow inner
                fileName    = Key name
              in
                return $ Right sparseTree

            bad ->
              return . Left . UnexpectedOutput $ UTF8.textShow bad


    (ExitFailure _, _, err) ->
      return . Left . UnknownAddErr $ UTF8.textShow err

    where
      opts = [ "add"
             , "-wq"
             , "--stdin-name"
             , unName name
             ]

pin :: MonadRIO          cfg m
    => HasLogFunc        cfg
    => Has HTTP.Manager  cfg
    => Has IPFS.URL      cfg
    => IPFS.CID
    -> m (Either IPFS.Error.Add CID)
pin (CID hash) = IPFS.Client.run (IPFS.Client.pin hash) >>= \case
  Right Pin.Response { cids } ->
    case cids of
      [cid] -> do
        logDebug $ "Pinned CID " <> display hash
        return $ Right cid

      _ ->
        logLeft $ UnexpectedOutput $ UTF8.textShow cids

  Left err ->
    logLeft err

-- | Unpin a CID
unpin :: MonadRIO          cfg m
      => Has HTTP.Manager  cfg
      => Has IPFS.URL      cfg
      => HasLogFunc        cfg
      => IPFS.CID
      -> m (Either IPFS.Error.Add CID)
unpin cid@(CID hash) = IPFS.Client.run (IPFS.Client.unpin hash False) >>= \case
  Right Pin.Response { cids } ->
    case cids of
      [cid'] -> do
        logDebug $ "Pinned CID " <> display hash
        return $ Right cid'

      _ ->
        logLeft $ UnexpectedOutput $ UTF8.textShow cids

  Left _ -> do
    logDebug $ "Cannot unpin CID " <> display hash <> " because it was not pinned"
    return $ Right cid

logLeft :: (MonadRIO cfg m, HasLogFunc cfg, Show a) => a -> m (Either IPFS.Error.Add b)
logLeft errStr = do
  let err = UnknownAddErr $ UTF8.textShow errStr
  logError $ display err
  return $ Left err
