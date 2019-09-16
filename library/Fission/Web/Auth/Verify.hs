module Fission.Web.Auth.Verify
  ( API
  , verify
  ) where

import RIO

import Servant

import Fission.Web.Server

type API = Get '[JSON] Bool

verify :: RIOServer cfg API
verify = pure True
