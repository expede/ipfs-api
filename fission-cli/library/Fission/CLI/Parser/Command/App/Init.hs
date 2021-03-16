module Fission.CLI.Parser.Command.App.Init
  ( parser
  , parserWithInfo
  -- * Reexport
  , module Fission.CLI.Parser.Command.App.Init.Types
  ) where

import           Options.Applicative

import           Fission.Prelude

import qualified Fission.App.Name                          as App

import           Fission.CLI.Parser.Command.App.Init.Types
import qualified Fission.CLI.Parser.Config.IPFS            as IPFS

parserWithInfo :: ParserInfo Options
parserWithInfo =
  parser `info` mconcat
    [ fullDesc
    , progDesc "Initialize an existing app"
    ]

parser :: Parser Options
parser = do
  ipfsCfg <- IPFS.parser

  appDir <- strOption $ mconcat
    [ help    "The file path to initialize the app in (app config, etc)"
    , showDefault
    -----------
    , long    "app-dir"
    , short   'a'
    -----------
    , value   "."
    , metavar "PATH"
    ]

  buildDir <- option mayBuild $ mconcat
    [ help    "The file path of the assets or directory to sync"
    -----------
    , value   Nothing
    , metavar "PATH"
    -----------
    , long    "build-dir"
    , short   'b'
    ]

  mayAppName <- option appName $ mconcat
    [ help    "Optional app name"
    -----------
    , long    "name"
    , short   'n'
    -----------
    , value   Nothing
    , metavar "NAME"
    ]

  return Options {..}

mayBuild :: ReadM (Maybe FilePath)
mayBuild = do
  raw <- str
  pure case raw of
    ""   -> Nothing
    path -> Just path

appName :: ReadM (Maybe App.Name)
appName =
  str >>= \case
    ""  ->
      return Nothing

    sub ->
      case App.mkName sub of
        Left _     -> fail "Not a valid app name"
        Right name -> return $ Just name
