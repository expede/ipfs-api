-- | Web error handling, common patterns, and other helpers
module Fission.Web.Server.Error
  ( ensure
  , ensureM
  , ensureMaybe
  , throw
  -- * Reexports
  , module Fission.Web.Server.Error.Class
  ) where

import           Fission.Prelude                                   hiding
                                                                   (ensure,
                                                                    ensureM)

import           Fission.Web.Server.Error.Class

import           Fission.Web.Server.Internal.Orphanage.ServerError ()

ensure ::
  ( MonadLogger m
  , MonadThrow  m
  , Display       err
  , ToServerError err
  )
  => Either err a
  -> m a
ensure = either throw pure

ensureM ::
  ( MonadLogger m
  , MonadThrow  m
  , Display       err
  , ToServerError err
  )
  => m (Either err a)
  -> m a
ensureM action = either throw pure =<< action

ensureMaybe ::
  ( MonadLogger m
  , MonadThrow m
  , Display       err
  , ToServerError err
  )
  => err
  -> Maybe a
  -> m a
ensureMaybe err = maybe (throw err) pure

throw ::
  ( MonadLogger m
  , MonadThrow  m
  , Display       err
  , ToServerError err
  )
  => err
  -> m a
throw err = do
  logError $ textDisplay err
  throwM $ toServerError err
