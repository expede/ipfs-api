{-# OPTIONS_GHC -fno-warn-orphans         #-}
{-# OPTIONS_GHC -fno-warn-missing-methods #-}

{-# LANGUAGE UndecidableInstances #-}

module Fission.Internal.Orphanage () where

import RIO
import RIO.Orphans ()
import qualified RIO.Partial as Partial

import Control.Lens (_1)

import Data.Aeson.Types
import Data.Scientific
import Data.Has
import Data.Pool
import Data.UUID as UUID

import Database.Selda
import Database.Selda.Backend

import Servant
import Servant.Multipart
import Servant.Swagger

import           Fission
import qualified Fission.Storage.Types as DB

instance Enum    UUID
instance SqlType UUID

instance Bounded UUID where
  minBound = Partial.fromJust $ UUID.fromString "00000000-0000-0000-0000-000000000000"
  maxBound = Partial.fromJust $ UUID.fromString "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"

instance ToJSON (ID a) where
  toJSON = Number . fromIntegral . fromId

instance FromJSON (ID a) where
  parseJSON = \case
    num@(Number n) ->
      case toBoundedInteger n of
        Nothing -> errMsg num
        Just i  -> return $ toId i

    invalid ->
      errMsg invalid

    where
      errMsg = modifyFailure ("parsing ID failed, " <>) . typeMismatch "Number"

instance Has DB.Pool cfg => MonadSelda (RIO cfg) where
  seldaConnection = do
    DB.Pool pool <- fromConfig
    liftIO $ withResource pool pure

instance HasLogFunc (LogFunc, b) where
  logFuncL = _1

instance HasLogFunc (LogFunc, b, c) where
  logFuncL = _1

instance HasSwagger api => HasSwagger (BasicAuth x r :> api) where
  toSwagger _ = toSwagger (Proxy :: Proxy api)

instance HasSwagger api => HasSwagger (MultipartForm Mem (MultipartData Mem) :> api) where
  toSwagger _ = toSwagger (Proxy :: Proxy api)
