module Fission.Test.Web.Auth.Token.UCAN.Resource (spec) where

import qualified Data.Aeson                                 as JSON

import           Fission.Web.Auth.Token.UCAN.Resource.Types

import           Fission.Test.Prelude

spec :: Spec
spec =
  describe "Resource" do
    describe "serialization" do
      itsProp' "serialized is isomorphic to ADT" \(resource :: Resource) ->
        JSON.eitherDecode (JSON.encode resource) `shouldBe` Right resource