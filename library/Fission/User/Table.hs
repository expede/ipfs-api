module Fission.User.Table
  ( name
  , users
  ) where

import Database.Selda

import qualified Fission.Platform.Heroku.AddOn as Heroku
import qualified Fission.Storage.Table  as Table
import           Fission.User.Types

-- | The name of the 'users' table
name :: Table.Name User
name = "users"

-- | The 'User' table
users :: Table User
users = table (Table.name name)
  [ #userID        :- autoPrimary
  , #username      :- index
  , #username      :- unique
  , #active        :- index
  , #secretDigest  :- index
  , #secretDigest  :- unique
  , #herokuAddOnId :- foreignKey Heroku.addOns #addOnID
  ]
