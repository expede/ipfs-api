module Fission.User.Creator.Class
  ( Creator (..)
  , Errors
  ) where

import           Data.UUID (UUID)
import           Database.Esqueleto

import           Fission.Models
import           Fission.Prelude

import qualified Fission.Platform.Heroku.Region.Types  as Heroku
import qualified Fission.Platform.Heroku.AddOn.Creator as Heroku.AddOn

import qualified Fission.User.Creator.Error as User
import qualified Fission.User.Password      as Password
import           Fission.User.DID           as DID

import           Fission.User.Username.Types
import           Fission.User.Role.Types
import           Fission.User.Email.Types

type Errors = OpenUnion
  '[ User.AlreadyExists
   , Heroku.AddOn.Error
   , Password.FailedDigest
   ]

class Heroku.AddOn.Creator m => Creator m where
  -- | Create a new, timestamped entry with optional heroku add-on
  create ::
       Username
    -> DID
    -> Maybe Email
    -> Maybe HerokuAddOnId
    -> UTCTime
    -> m (Either Errors UserId)

  -- | Create a new, timestamped entry and heroku add-on
  createWithHeroku ::
       UUID
    -> Heroku.Region
    -> Username
    -> Text
    -> UTCTime
    -> m (Either Errors UserId)

instance MonadIO m => Creator (Transaction m) where
  create username did email herokuAddOnId now =
    User
      { userDid           = Just did
      , userUsername      = username
      , userEmail         = email
      , userRole          = Regular
      , userActive        = True
      , userHerokuAddOnId = herokuAddOnId
      , userSecretDigest  = Nothing
      , userInsertedAt    = now
      , userModifiedAt    = now
      }
    |> insertUnique
    |> bind \case
      Just userID ->
        return (Right userID)

      Nothing ->
        return . Left <| openUnionLift User.AlreadyExists

  createWithHeroku herokuUUID herokuRegion username password now =
    Heroku.AddOn.create herokuUUID herokuRegion now >>= \case
      Left err ->
        return . Left <| openUnionLift err

      Right herokuAddOnId ->
        Password.hashPassword password >>= \case
          Left err ->
            return . Left <| openUnionLift err

          Right secretDigest ->
            User
              { userDid           = Nothing
              , userUsername      = username
              , userEmail         = Nothing
              , userRole          = Regular
              , userActive        = True
              , userHerokuAddOnId = Just herokuAddOnId
              , userSecretDigest  = Just secretDigest
              , userInsertedAt    = now
              , userModifiedAt    = now
              }
            |> insertUnique
            |> bind \case
              Just userID ->
                return (Right userID)

              Nothing ->
                return . Left <| openUnionLift User.AlreadyExists
