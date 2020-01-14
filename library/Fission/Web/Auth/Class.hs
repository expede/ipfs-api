module Fission.Web.Auth.Class (MonadAuth (..)) where

import           Servant
import           Fission.Prelude

class Monad m => MonadAuth who m where
  -- | Check that some entity is authenticated and authorized
  verify :: m (BasicAuthCheck who)
