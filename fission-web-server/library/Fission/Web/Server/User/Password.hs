module Fission.Web.Server.User.Password
  ( random
  , hashPassword
  , module Fission.User.Password.Types
  , module Fission.Web.Server.User.Password.Error
  ) where

import           Crypto.BCrypt                          hiding (hashPassword)

import           Fission.Prelude

import           Fission.Random                         as Random

import           Fission.User.Password.Types
import qualified Fission.User.Password.Types            as User

import           Fission.Web.Server.User.Password.Error

-- | Generate a password for a `User`.
random :: MonadIO m => m User.Password
random = do
  pass <- Random.alphaNum 50
  return $ User.Password pass

hashPassword :: MonadIO m => User.Password -> m (Either FailedDigest Text)
hashPassword User.Password {password} = do
  liftIO (hashPasswordUsingPolicy slowerBcryptHashingPolicy $ encodeUtf8 password) >>= \case
    Nothing           -> return $ Left FailedDigest
    Just secretDigest -> return . Right $ decodeUtf8Lenient secretDigest
