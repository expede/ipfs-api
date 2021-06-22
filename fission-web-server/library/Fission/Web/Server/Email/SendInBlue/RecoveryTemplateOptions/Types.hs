module Fission.Web.Server.Email.SendInBlue.RecoveryTemplateOptions.Types (RecoveryTemplateOptions(..)) where

import           Fission.Prelude

import           Fission.User.Username.Types

data RecoveryTemplateOptions = RecoveryTemplateOptions
  { recoveryLink :: Text
  , username     :: Username
  }

instance ToJSON RecoveryTemplateOptions where
  toJSON RecoveryTemplateOptions { recoveryLink, username } =
    Object [ ("RECOVERY_LINK", toJSON recoveryLink )
           , ("USERNAME",    toJSON username )
           ]
