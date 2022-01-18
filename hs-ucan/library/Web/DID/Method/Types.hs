module Web.DID.Method.Types (Method (..)) where

import           Data.Aeson
import           RIO
import           Test.QuickCheck

data Method
  = Key
  deriving (Show, Eq)

instance Display Method where
  display Key = "key"

instance Arbitrary Method where
  arbitrary = elements [Key]

instance ToJSON Method where
  toJSON Key = "key"

instance FromJSON Method where
  parseJSON = withText "DID.Method" \case
    "key" -> return Key
    other -> fail $ show other <> " is not an acceptable DID method"
