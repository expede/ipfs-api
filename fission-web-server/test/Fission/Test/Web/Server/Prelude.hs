module Fission.Test.Web.Server.Prelude
  ( module Fission.Prelude
  , module Fission.Web.Server.Mock
  --
  , module Test.Tasty
  , module Test.Tasty.Hspec
  , module Test.Hspec.Wai
  , module Test.QuickCheck
  --
  , bodyMatches
  , itsProp
  , itsProp'
  , shouldHaveRun
  ) where

import qualified Network.HTTP.Types         as HTTP

import           Test.Tasty                 (TestTree, defaultMain, testGroup)
import           Test.Tasty.Hspec

import           Test.Hspec.Core.QuickCheck (modifyMaxSuccess)
import           Test.Hspec.Wai             hiding (pending, pendingWith)

import           Test.QuickCheck            hiding (Result (..))
import           Test.QuickCheck.Instances  ()

import           Fission.Prelude            hiding (Result (..), log)

import           Fission.Web.Server.Mock

-- | Prop test with description
itsProp :: (HasCallStack, Testable a) => String -> Int -> a -> SpecWith ()
itsProp description times prop =
  modifyMaxSuccess (\_ -> times) . it ("🔀 " <> description) $ property prop

-- | Prop test with the default number of tries (100)
itsProp' :: (HasCallStack, Testable a) => String -> a -> SpecWith ()
itsProp' description prop = it ("🔀 " <> description) $ property prop

bodyMatches :: Value -> [HTTP.Header] -> Body -> Maybe String
bodyMatches expected _ jsonBody =
  case decode jsonBody of -- NB: Here success is Nothing, and errors are Just
      Just val | val == expected -> Nothing
      _                          -> Just "Body does not match"

shouldHaveRun ::
  ( Eq   (OpenUnion logs)
  , Show (OpenUnion logs)
  , IsMember eff logs
  )
  => [OpenUnion logs]
  -> eff
  -> Expectation
shouldHaveRun effLog eff = effLog `shouldContain` [openUnionLift eff]
