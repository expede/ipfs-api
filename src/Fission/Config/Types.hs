-- | Configuration types
module Fission.Config.Types
  ( Config (..)
  , processCtx
  , logFunc
  , ipfsPath
  , ipfsTimeout
  , host
  , dbPath
  , dbPool
  , herokuID
  , herokuPassword
  ) where

import RIO
import RIO.List (intercalate)
import RIO.Process (ProcessContext, HasProcessContext (..))

import Control.Lens (makeLenses)
import Data.Has

import           Fission.Web.Types
import qualified Fission.IPFS.Types            as IPFS
import qualified Fission.Storage.Types         as DB
import qualified Fission.Platform.Heroku.Types as Heroku

-- | The top level 'Fission' application 'RIO' configuration
data Config = Config
  { _processCtx     :: !ProcessContext
  , _logFunc        :: !LogFunc
  , _ipfsPath       :: !IPFS.BinPath
  , _ipfsTimeout    :: !IPFS.Timeout
  , _host           :: !Host
  , _dbPath         :: !DB.Path
  , _dbPool         :: !DB.Pool
  , _herokuID       :: !Heroku.ID
  , _herokuPassword :: !Heroku.Password
  }

makeLenses ''Config

instance Show Config where
  show Config {..} = intercalate "\n"
    [ "Config {"
    , "  _processCtx     = **SOME PROC CONTEXT**"
    , "  _logFunc        = **SOME LOG FUNCTION**"
    , "  _ipfsPath       = " <> show _ipfsPath
    , "  _ipfsTimeout    = " <> show _ipfsTimeout
    , "  _host           = " <> show _host
    , "  _dbPath         = " <> show _dbPath
    , "  _dbPool         = " <> show _dbPool
    , "  _herokuID       = " <> show _herokuID
    , "  _herokuPassword = " <> show _herokuPassword
    , "}"
    ]

instance HasProcessContext Config where
  processContextL = processCtx

instance HasLogFunc Config where
  logFuncL = logFunc

instance Has IPFS.BinPath Config where
  hasLens = ipfsPath

instance Has IPFS.Timeout Config where
  hasLens = ipfsTimeout

instance Has DB.Path Config where
  hasLens = dbPath

instance Has DB.Pool Config where
  hasLens = dbPool

instance Has Heroku.ID Config where
  hasLens = herokuID

instance Has Heroku.Password Config where
  hasLens = herokuPassword

instance Has Host Config where
  hasLens = host
