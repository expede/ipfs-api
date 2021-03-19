module Fission.Internal.Bool
  ( anyX
  , truthy
  ) where

import           Fission.Prelude

anyX :: [a -> Bool] -> a -> Bool
anyX preds value = True `elem` (preds <*> [value])

-- | Test if any string-like item is truthy.
truthy :: (Eq a, IsString a) => a -> Bool
truthy = anyX $ (==) <$> ["true", "yes", "1", "t", "on"]
