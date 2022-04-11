{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE QuasiQuotes #-}
module Test.Web.UCAN.Attenuation (spec) where

import           Control.Lens
import           Control.Monad.Time
import qualified Data.Aeson.Types                      as JSON
import qualified RIO.Set                               as Set
import           RIO.Time
import           Test.Web.DID.Fixtures
import qualified Test.Web.UCAN.DelegationSemantics     as DelegationSemantics
import qualified Test.Web.UCAN.Example                 as Ex
import           Test.Web.UCAN.Orphanage.DummyResolver ()
import           Test.Web.UCAN.Prelude
import qualified Text.URI.QQ                           as URI
import           Web.DID.Types
import           Web.UCAN.Capabilities
import           Web.UCAN.Capabilities.Class
import           Web.UCAN.Types
import           Web.UCAN.Witness


spec :: Spec
spec =
  describe "Attenuation" do
    describe "capabilities" do
      itsPropSized "produces parenthood proofs on UCANs without proofs" 6 \(ucan :: UCAN () Ex.Resource Ex.Ability) -> do
        delegations <- capabilities ucan{ claims = (claims ucan){ proofs = [] } }
        let isIntroducedByParenthood = \case
              Right (DelegatedAuthorization _ _ _ IntroducedByParenthood) -> True
              Right (DelegatedAuthentication _) -> True -- ignored
              Left _ -> True -- ignored as well
              _ -> False
        all isIntroducedByParenthood delegations `shouldBe` True

      itsPropSized "produces only valid proofs" 6 \(ucan :: UCAN () Ex.Resource Ex.Ability) -> do
        proofs <- capabilities ucan
        all (either (const True) checkDelegationChain) proofs `shouldBe` True

      describe "fixtures" do
        -- TODO Test UCAN spec fixtures.

        it "works with partial-order delgation semantics" do
          tomorrow <- addUTCTime nominalDay <$> currentTime
          let
            leafUcan :: UCAN JSON.Value Ex.PathResource Ex.MsgAbility
            leafUcan = signEd25519 aliceKey Claims
              { sender = aliceDID
              , receiver = bobDID
              , attenuation =
                [ CapResource (pathResource "path:/public/test") (Ability Ex.MsgSend)
                , CapResource (pathResource "path:/public/Apps") (Ability Ex.MsgSend)
                ]
              , proofs = []
              , facts = []
              , expiration = tomorrow
              , notBefore = Nothing
              , nonce = Nothing
              }

            ucan :: UCAN JSON.Value Ex.PathResource Ex.MsgAbility
            ucan = signEd25519 bobKey Claims
              { sender = bobDID
              , receiver = malloryDID
              , attenuation =
                [ CapResource (pathResource "path:/public/test/file.txt") (Ability Ex.MsgSend)
                , CapResource (pathResource "path:/public/abc") (Ability Ex.MsgSend)
                ]
              , proofs = [ Nested $ textDisplay leafUcan ]
              , facts = []
              , expiration = tomorrow
              , notBefore = Nothing
              , nonce = Nothing
              }

            expectedDelegations =
              [ ( (pathResource "path:/public/test/file.txt", Ability Ex.MsgSend)
                , aliceDID
                )
              , ( (pathResource "path:/public/test/file.txt", Ability Ex.MsgSend)
                , bobDID
                )
              , ( (pathResource "path:/public/abc", Ability Ex.MsgSend)
                , bobDID
                )
              ]

          actualDelegations <- capsWithRootIssuers <$> capabilities ucan

          Set.fromList actualDelegations `shouldBe`
            Set.fromList expectedDelegations

        it "extends capability root issuers through `as:` and `my:`" do
          tomorrow <- addUTCTime nominalDay <$> currentTime
          let
            leafUcan :: UCAN JSON.Value Ex.Resource Ex.Ability
            leafUcan = signEd25519 aliceKey Claims
              { sender = aliceDID
              , receiver = bobDID
              , attenuation = [ CapOwnedResources (OwnedResources Nothing (OnlyScheme [URI.scheme|example|] Ex.CanTouch)) ]
              , proofs = []
              , facts = []
              , expiration = tomorrow
              , notBefore = Nothing
              , nonce = Nothing
              }

            ucan :: UCAN JSON.Value Ex.Resource Ex.Ability
            ucan = signEd25519 bobKey Claims
              { sender = bobDID
              , receiver = malloryDID
              , attenuation = [ CapResource Ex.Everything (Ability Ex.CanTouch) ]
              , proofs = [ Nested $ textDisplay leafUcan ]
              , facts = []
              , expiration = tomorrow
              , notBefore = Nothing
              , nonce = Nothing
              }

            expectedDelegations =
              [ -- short-circuited "by parenthood"
                ( (Ex.Everything, Ability Ex.CanTouch)
                , bobDID
                )
              , -- extended root issuer through my: capability
                ( (Ex.Everything, Ability Ex.CanTouch)
                , aliceDID
                )
              ]

          actualDelegations <- capsWithRootIssuers <$> capabilities ucan

          Set.fromList actualDelegations `shouldBe`
            Set.fromList expectedDelegations

        it "delegates ownership through `as:` and `my:`" do
          tomorrow <- addUTCTime nominalDay <$> currentTime
          let
            leafUcan :: UCAN JSON.Value Ex.Resource Ex.Ability
            leafUcan = signEd25519 aliceKey Claims
              { sender = aliceDID
              , receiver = bobDID
              , attenuation = [ CapOwnedResources (OwnedResources Nothing All) ]
              , proofs = []
              , facts = []
              , expiration = tomorrow
              , notBefore = Nothing
              , nonce = Nothing
              }

            ucan :: UCAN JSON.Value Ex.Resource Ex.Ability
            ucan = signEd25519 bobKey Claims
              { sender = bobDID
              , receiver = malloryDID
              , attenuation = [ CapOwnedResources (OwnedResources (Just aliceDID) All) ]
              , proofs = [ Nested $ textDisplay leafUcan ]
              , facts = []
              , expiration = tomorrow
              , notBefore = Nothing
              , nonce = Nothing
              }

          actualDelegations <- toListOf (traversed . _Right) <$> capabilities ucan

          Set.fromList actualDelegations `shouldBe`
            Set.fromList
              [ DelegatedAuthentication (DelegateAs aliceDID All ucan (DelegateMy All leafUcan)) ]

      describe "PathResource" do
        DelegationSemantics.itHasPartialOrderProperties @Ex.PathResource

        it "public/ can delegate public/test" do
          (pathResource "path:/public" `canDelegate` pathResource "path:/public/test")
            `shouldBe` True

        it "public/ can not delegate private/" do
          (pathResource "path:/public" `canDelegate` pathResource "path:/private")
            `shouldBe` False

        it "public/test can not delegate public/" do
          (pathResource "path:/public/test" `canDelegate` pathResource "path:/public")
            `shouldBe` False



capsWithRootIssuers :: [Either a (DelegationChain fct res abl)] -> [((res, Ability abl), DID)]
capsWithRootIssuers = concatMap \case
  Right proof@(DelegatedAuthorization res abl _ _) -> [((res, abl), rootIssuer proof)]
  _                                            -> []


pathResource :: Text -> Ex.PathResource
pathResource text = case parseResource text of
  JSON.Success path -> path
  JSON.Error message -> error $ "Couldn't parse PathResource fixture: " <> message
