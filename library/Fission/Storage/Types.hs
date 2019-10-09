module Fission.Storage.Types
  ( Pool (..)
  , SeldaPool
  ) where

import RIO

import qualified Data.Pool                 as Database
import           Database.Selda.Backend    (SeldaConnection)
import           Database.Selda.PostgreSQL

type SeldaPool = Database.Pool (SeldaConnection PG)

newtype Pool = Pool { getPool :: SeldaPool }
  deriving Show
