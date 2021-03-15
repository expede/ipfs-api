module Fission.CLI.Key.Store
  ( create
  , forceCreate
  , fetch
  , delete
  , persist
  , exists
  , getAsBytes

  -- * Reexport

  , module Fission.CLI.Key.Store.Class
  , module Fission.CLI.Key.Store.Types
  ) where

import qualified Data.ByteArray                   as ByteArray
import           RIO.Directory

import           Fission.Prelude

import           Fission.Key.Error                as Key

import           Fission.CLI.File
import qualified Fission.CLI.Key.Store.Class      as KeyStore

import qualified Fission.Internal.Base64          as B64
import qualified Fission.Internal.Base64.Scrubbed as B64.Scrubbed

-- 🔁 Reexports

import           Fission.CLI.Key.Store.Class
import           Fission.CLI.Key.Store.Types

create ::
  ( MonadIO       m
  , MonadLogger   m
  , MonadKeyStore m key
  , MonadRaise    m
  , m `Raises` Key.Error
  )
  => Proxy key
  -> m ()
create keyRole =
  exists keyRole >>= \case
    True  -> raise Key.AlreadyExists
    False -> forceCreate keyRole

forceCreate ::
  ( MonadIO       m
  , MonadLogger   m
  , MonadKeyStore m key
  )
  => Proxy key
  -> m ()
forceCreate keyRole = persist keyRole =<< KeyStore.generate keyRole

persist ::
  ( MonadIO       m
  , MonadLogger   m
  , MonadKeyStore m key
  )
  => Proxy     key
  -> SecretKey key
  -> m ()
persist keyRole key = do
  path <- KeyStore.getPath keyRole
  forceWrite path $ B64.toByteString key

fetch ::
  ( MonadIO       m
  , MonadKeyStore m key
  , MonadRaise    m
  , m `Raises` Key.Error
  )
  => Proxy key
  -> m (SecretKey key)
fetch keyRole = do
  scrubbed <- getAsBytes keyRole
  ensureM $ parse keyRole scrubbed

getAsBytes ::
  ( MonadIO       m
  , MonadKeyStore m key
  , MonadRaise    m
  , m `Raises` Key.Error
  )
  => Proxy key
  -> m ByteArray.ScrubbedBytes
getAsBytes keyRole =
  exists keyRole >>= \case
    False ->
      raise Key.DoesNotExist

    True -> do
      path <- KeyStore.getPath keyRole
      bs   <- readFileBinary path
      return $ B64.Scrubbed.scrub bs

exists :: (MonadIO m, MonadKeyStore m key) => Proxy key -> m Bool
exists keyRole = doesFileExist =<< KeyStore.getPath keyRole

delete :: (MonadIO m, MonadKeyStore m key) => Proxy key -> m ()
delete keyRole =
  exists keyRole >>= \case
    False -> return ()
    True  -> removeFile =<< KeyStore.getPath keyRole
