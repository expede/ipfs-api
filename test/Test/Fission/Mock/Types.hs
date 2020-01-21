{-# LANGUAGE UndecidableInstances #-}

module Test.Fission.Mock.Types
  ( Mock (..)
  , MockSession (..)
  , RunDB (..)
  , GetVerifier (..)
  ) where

import           Control.Monad.Writer
import           Data.Generics.Product
import Database.Esqueleto
import qualified Network.IPFS.Types  as IPFS
import           Servant

import           Test.Fission.Mock.Effect

import           Fission.Prelude
import           Fission.IPFS.Linked.Class
import           Fission.Web.Auth.Class
import           Fission.Models

import qualified Fission.Platform.Heroku.Auth.Types as Heroku

-- | The result of running a mocked test session
data MockSession log a = MockSession
  { effectLog :: [OpenUnion log] -- ^ List of effects that were run
  , result    :: a               -- ^ Pure return value
  }

{- | Fission's mock type

     Notes:
     * We will likely want @State@ in here at some stage
     * @RIO@ because lots of constraints want @MonadIO@
       * Avoid actual @IO@, or we're going to have to rework this 😉

-}
newtype Mock effs ctx a = Mock
  { unMock :: WriterT [OpenUnion effs] (RIO ctx) a }
  deriving
    newtype ( Functor
            , Applicative
            , Monad
            , MonadWriter [OpenUnion effs]
            , MonadReader ctx
            , MonadIO
            )
-- RunDB

data RunDB = RunDB
  deriving (Show, Eq)

instance IsMember RunDB effs => MonadDB (Mock effs cfg) (Mock effs cfg) where
  runDB mock = do
    logEff RunDB
    mock

-- IPFSLinkedPeer

newtype LinkedPeer = LinkedPeer IPFS.Peer
  deriving (Show, Eq)

instance IsMember LinkedPeer logs => MonadLinkedIPFS (Mock logs cfg) where
  getLinkedPeers = do
    let fakePeer = IPFS.Peer "/ip4/FAKE_PEER"
    logEff <| LinkedPeer fakePeer
    return <| pure fakePeer

-- Auth

data GetVerifier = GetVerifier
  deriving (Show, Eq)

instance
  ( IsMember GetVerifier effs
  , HasField' "authCheckText" ctx (BasicAuthCheck Text)
  )
  => MonadAuth Text (Mock effs ctx) where
  verify = do
    logEff GetVerifier
    asks (getField @"authCheckText")

instance
  ( IsMember GetVerifier effs
  , HasField' "authCheckUser" ctx (BasicAuthCheck (Entity User))
  )
  => MonadAuth (Entity User) (Mock effs ctx) where
  verify = do
    logEff GetVerifier
    asks (getField @"authCheckUser")

instance
  ( IsMember GetVerifier effs
  , HasField' "authCheckHeroku" ctx (BasicAuthCheck Heroku.Auth)
  )
  => MonadAuth Heroku.Auth (Mock effs ctx) where
  verify = do
    logEff GetVerifier
    asks (getField @"authCheckHeroku")
