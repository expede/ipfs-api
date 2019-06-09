module Fission.Monitor
  ( Config (..)
  , wai
  ) where

import RIO

import System.Envy
import System.Remote.Monitoring.Wai

data Config = Config
  { ekgHost :: ByteString
  , ekgPort :: Int
  } deriving (Generic, Show)

instance DefConfig Config where
  defConfig = Config "localhost" 9630

instance FromEnv Config

wai :: HasLogFunc env => RIO env ()
wai = liftIO (decodeEnv :: IO (Either String Config)) >>= \case
  Left err -> do
    logError $ displayShow err
    Config { ekgHost, ekgPort } <- return defConfig
    liftIO . void $ forkServer ekgHost ekgPort

  Right Config { ekgHost, ekgPort } -> do
    logInfo $ mconcat
      [ "EKG available at "
      , displayBytesUtf8 ekgHost
      , ":"
      , display ekgPort
      , "\n"
      ]

    liftIO . void $ forkServer ekgHost ekgPort
