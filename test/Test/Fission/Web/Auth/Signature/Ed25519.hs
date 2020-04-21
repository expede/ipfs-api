module Test.Fission.Web.Auth.Signature.Ed25519 (tests) where

import qualified Crypto.PubKey.Ed25519 as Ed25519

import           Fission.Web.Auth.Token.JWT
import qualified Fission.Key as Key
import           Fission.User.DID

import qualified Fission.Internal.Base64     as B64
import qualified Fission.Internal.Base64.URL as B64.URL
 
import           Fission.Key.Asymmetric.Algorithm.Types as Alg
import           Fission.Web.Auth.Token.JWT.Validation

import           Test.Fission.Prelude

tests :: SpecWith ()
tests =
  describe "Fission.Web.Auth.Signature.Ed25519" do
    describe "signature verification" do
      itsProp' "verifies" \(jwt@JWT {..}, sk) ->
        let
          pk         = Ed25519.toPublic sk
          header'    = header { alg = Alg.Ed25519 }
          claims'    = claims { sender = did }
          sig'       = signEd25519 header' claims' sk
          rawContent = B64.URL.encodeJWT header' claims'

          did = DID
            { publicKey = Key.Public $ B64.toB64ByteString pk
            , algorithm = Alg.Ed25519
            , method    = Key
            }

          jwt' = jwt
            { header = header'
            , claims = claims'
            , sig    = sig'
            }

        in
          checkEd25519Signature rawContent jwt' `shouldBe` Right jwt'
