module Fission.Web.Auth.DID (handler) where

import           Network.Wai

import           Fission.Prelude

import           Fission.Web.Auth.Types as Auth
import           Fission.Web.Auth.Token as Token
import qualified Fission.Web.Auth.Error as Auth
import qualified Fission.Web.Auth.JWT   as JWT

import           Fission.User.DID.Types

import qualified Fission.Web.Auth.Token.Bearer.Types as Bearer

-- | Auth handler for registering DIDs
-- Ensures properly formatted token but does not check against DB
handler ::
  ( MonadIO     m
  , MonadLogger m
  , MonadThrow  m
  , MonadTime   m
  )
  => Request
  -> m DID
handler req =
  case Token.get req of
    Just (Bearer token@(Bearer.Token jwt (Just rawContent))) ->
      JWT.check rawContent jwt >>= \case
        Left err -> do
          logWarn $ "Failed registration with token " <> encode token
          throwM err

        Right JWT.JWT {claims = JWT.Claims {iss}} ->
          return iss

    _ ->
      throwM Auth.NoToken
