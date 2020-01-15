module Fission.User
  ( module Fission.User.Retriever
  , module Fission.User.Creator
  , module Fission.User.Modifier
  , module Fission.User.Destroyer
  , module Fission.User.Types
  , module Fission.User.Registration.Types
  , CRUD
  ) where

import Fission.User.Retriever
import Fission.User.Creator
import Fission.User.Modifier
import Fission.User.Destroyer
import Fission.User.Types
import Fission.User.Registration.Types

type CRUD m
  = ( Retriever m
    , Creator   m
    , Modifier  m
    , Destroyer m
    )
