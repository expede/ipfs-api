{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Fission where

import RIO

import Network.Wai (Application)
import Network.Wai.Handler.Warp

import Fission.Env
import Fission.Internal.Constraint (WithRIO, Loggable)

-- | Top-level application type
type Fission = RIO Env ()

-- Examples:
--
-- >>> 1 == 1
-- Truei
startAtPort :: (WithRIO m env, Loggable env) => Application -> Word -> m ()
startAtPort webApp port = do
  logInfo $ "Servant running at port " <> display port
  liftIO $ fromIntegral port `run` webApp

-- -- | This returns a 'Middleware' based on the environment that we're in.
-- setLogger :: RunEnvironment -> Middleware
-- setLogger = \case
--   Test        -> id
--   Development -> logStdoutDev
--   Production  -> logStdout
