module Fission.Web.API.User.Types (RoutesV_ (..), RoutesV2 (..)) where

import           Fission.Web.API.Prelude

import qualified Fission.Web.API.Relay.Types               as Relay
import qualified Fission.Web.API.User.Create.Types         as Create
import qualified Fission.Web.API.User.DID.Types            as DID
import qualified Fission.Web.API.User.DataRoot.Types       as DataRoot
import qualified Fission.Web.API.User.Email.Types          as Email
import qualified Fission.Web.API.User.ExchangeKey.Types    as ExchangeKeys
import qualified Fission.Web.API.User.Password.Reset.Types as Password
import           Fission.Web.API.User.Verify.Types
import qualified Fission.Web.API.User.WhoAmI.Types         as WhoAmI

data RoutesV2 mode = RoutesV2
  { create       :: mode :- Create.WithDID
  , dataRoot     :: mode :- "data"             :> ToServantApi DataRoot.Routes
  , email        :: mode :- "email"            :> ToServantApi Email.Routes
  , did          :: mode :- "did"              :> ToServantApi DID.Routes
  , whoAmI       :: mode :- "whoami"           :> ToServantApi WhoAmI.Routes
  , linkingRelay :: mode :- "user"   :> "link" :> ToServantApi Relay.Routes
  }
  deriving Generic

data RoutesV_ mode = RoutesV_
  { create        :: mode :- ToServantApi Create.RoutesV_
  , whoAmI        :: mode :- ToServantApi WhoAmI.Routes
  , email         :: mode :- "email"              :> ToServantApi Email.Routes
  , did           :: mode :- "did"                :> ToServantApi DID.Routes
  , exchangeKeys  :: mode :- "exchange" :> "keys" :> ToServantApi ExchangeKeys.Routes
  , linkingRelay  :: mode :- "user"     :> "link" :> ToServantApi Relay.Routes
  , dataRoot      :: mode :- "data"               :> ToServantApi DataRoot.Routes
  , passwordReset :: mode :- Password.Reset
  , verify        :: mode :- Verify
  }
  deriving Generic
