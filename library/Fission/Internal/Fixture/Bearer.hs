{-# OPTIONS_GHC -fno-warn-incomplete-uni-patterns #-}

module Fission.Internal.Fixture.Bearer
  ( jsonRSA2048
  , tokenRSA2048
  , jwtRSA2048
  , rawContent
  , validTime
  ) where

import           Servant.API

import           Fission.Prelude
import qualified Fission.Web.Auth.Token.Bearer.Types as Bearer
import           Fission.Web.Auth.Token.JWT

validTime :: UTCTime
validTime = fromSeconds 0 -- i.e. waaaay before the expiry :P

rawContent :: Text
rawContent = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsInVhdiI6IjAuMS4wIn0.eyJhdWQiOiJkaWQ6a2V5OnpCUjRtM0ROWkhUMUc4TmIyUkh6Z0tLN1RyV3hFbUpqWnNrZ3ZGZG5jVHRoelVIem5neU5LbUt4NFZLV0VKRTZzazRTRTRLYTNrSDkyTXhVMllDN0NjZVBIeTc3R3paeTgiLCJleHAiOjE1ODc1NzcxNTIsImlzcyI6ImRpZDprZXk6ejEzVjNTb2cyWWFVS2hkR0NtZ3g5VVp1VzFvMVNoRkpZYzZEdkdZZTdOVHQ2ODlOb0wzNnBHaTF3bWVVS01GZmdqVEE3WkZYNHVyUmpVbkhYYXF5RHY3c2tBZ3NWYTVEQ3Vpd2JuVGhWaEhacGJVSExkRlZzc0s1V0R2VjY1ZHJ5dFF0Y0hIcEhMRURrQmFQV1U2TWhDb2tiMmpTRVRwaWNxRlpidmZmRENMdEExakZIYXB6SkRxbVB4V3pWQWZzcllQcHY2cmhiYWROa0ZrNzdjRFRkc1hGWDltV3VRNGhtb0x0RmVqNWlidTdZTFNKZkI3UmFWa1FUZkVxcWF4azFkdzVLbWlYTjhQb3Q2Y3R0YjJ5SnJ2TDFXZTF5bXh0cnR3UkFvRkpxazJHTHNwTVdFaFJVa2tWczZqWHY0SlVkUjU1Y1A5cm1QeXFmQUhIclY3QW5BYnJ4eE1DdVhNa2I5YUF2b2llVlBuN1luamNYdXRqbW9ReTJHdGIxeThhR1NmUXhLVlpSRDJIeEU1eHhFeXB0TU4iLCJwcmYiOm51bGwsInB0eSI6IkFQUEVORCIsInNjcCI6Ii8ifQ"

jsonRSA2048 :: Text
jsonRSA2048 = "Bearer " <> rawContent <> ".nmM5TuJQycYQ5i0AOCDfh67eN7wHMM3mcVeCpLFYa27e9tyd_Fzqnv0ks5dAiq_c42eKqO5BVkRfCpsXLzkdpaqXR6tDO3HY9VgtT2a3m1gFLDpkdknMKIL1xiPcgA-hcHmDmTDYnvRe7T3l4W98t-RTrmknlLRIivYAZjXVpbdROk9RiP1TCzaiHBH7JXDcGV901eFv970DtbdQVRDsVTcC9w8iaLE2jibd1ld29NMIYGpDX5FIKUjsIqgNGef5Kx7pHQe_MKvPkBoCd1fYVyi9mhxUFZnlOOqra0LfPfnXKPMEtfFe6K8HAPvvpquWgbK_g8wdlKp3Xi-9cHkEJQ"

tokenRSA2048 :: Bearer.Token
jwtRSA2048   :: JWT

Right tokenRSA2048@(Bearer.Token jwtRSA2048 _) = parseUrlPiece jsonRSA2048
