module Web.Ucan.Resolver.Class (Resolver (..)) where

import           Network.IPFS.CID.Types

import           RIO

import qualified Web.Ucan.RawContent     as Ucan
import           Web.Ucan.Resolver.Error as Resolver

class Monad m => Resolver m where
  resolve :: CID -> m (Either Resolver.Error Ucan.RawContent)
