module Test.Fission.Web.Auth.Token.JWT.Validation (tests) where

import qualified Fission.Internal.Fixture.Bearer       as Fixture
import qualified Fission.Web.Auth.Token.JWT.Validation as JWT

import           Test.Fission.Prelude

tests :: SpecWith ()
tests =
  describe "JWT Validation" do
    context "RSA 2048" do
      context "real world bearer token" do
        it "is valid" do
          JWT.pureChecks Fixture.rawContent Fixture.jwtRSA2048 Fixture.validTime
            `shouldBe` Right Fixture.jwtRSA2048
