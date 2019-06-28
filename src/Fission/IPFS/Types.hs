module Fission.IPFS.Types
  ( Opt
  , CID (..)
  , mkCID
  , Name (..)
  , Peer (..)
  , Path (..)
  , SparseTree (..)
  , linearize
  , Tag (..)
  ) where

import           RIO
import qualified RIO.Text as Text

import Control.Lens ((.~), (?~))
import Data.Aeson
import Data.Aeson.TH
import Data.Swagger (ToSchema (..), NamedSchema (..), SwaggerType (..), type_, example)

import Servant
import System.Envy

import qualified Fission.Internal.UTF8 as UTF8

type Opt  = String

-- | CID path
--
-- Exmaple
--
-- > "QmcaHAFzUPRCRaUK12dC6YyhcqEEtdfg94XrPwgCxZ1ihD/myfile.txt"
newtype Path = Path { unpath :: Text }
  deriving          ( Eq
                    , Generic
                    , Show
                    , Ord
                    )
  deriving anyclass ( ToSchema )
  deriving newtype  ( IsString )

newtype Name = Name { unName :: String }
  deriving          ( Eq
                    , Generic
                    , Show
                    , Ord
                    )
  deriving anyclass ( ToSchema )
  deriving newtype  ( IsString )

$(deriveJSON defaultOptions ''Name)

newtype CID = CID { unaddress :: Text }
  deriving          ( Eq
                    , Ord
                    , Show
                    )
  deriving newtype  ( IsString )

$(deriveJSON defaultOptions ''CID)

-- | Smart constructor for @CID@
mkCID :: Text -> CID
mkCID = CID . Text.strip

instance ToSchema CID where
  declareNamedSchema _ =
     return $ NamedSchema (Just "IPFS Address") $ mempty
            & type_   .~ SwaggerString
            & example ?~ "QmW2WQi7j6c7UgJTarActp7tDNikE4B2qXtFCfLPdsgaTQ"

data Tag
  = Key Name
  | Hash CID
  deriving          ( Eq
                    , Generic
                    , Ord
                    , Show
                    )
  deriving anyclass ( ToSchema )

$(deriveJSON defaultOptions ''Tag)

-- | Path to the IPFS binary
newtype BinPath = BinPath { getBinPath :: FilePath }
  deriving          ( Show
                    , Generic
                    )
  deriving anyclass ( ToSchema )
  deriving newtype  ( IsString )

instance FromEnv BinPath where
  fromEnv = BinPath <$> env "IPFS_PATH"

newtype Peer = Peer { peer :: Text }
  deriving          ( Show
                    , Generic
                    )
  deriving newtype  ( IsString )

$(deriveJSON defaultOptions ''Peer)

instance ToSchema Peer where
  declareNamedSchema _ =
     return $ NamedSchema (Just "IPFS Peer") $ mempty
            & type_   .~ SwaggerString
            & example ?~ "/ip4/178.62.158.247/tcp/4001/ipfs/QmSoLer265NRgSp2LA3dPaeykiS1J6DifTC88f5uVQKNAd"

instance Display CID where
  textDisplay = unaddress

instance MimeRender PlainText CID where
  mimeRender _ = UTF8.textToLazyBS . unaddress

instance MimeRender OctetStream CID where
  mimeRender _ = UTF8.textToLazyBS . unaddress

-- | Directory structure for CIDs and other identifiers
--
-- Examples:
--
-- > Content "abcdef"
--
-- > show $ Directory [(Key "abcdef", Stub "myfile.txt")])]
-- "abcdef/myfile.txt"
data SparseTree
  = Stub Name
  | Content CID
  | Directory (Map Tag SparseTree)
  deriving          ( Eq
                    , Generic
                    , Show
                    )

linearize :: SparseTree -> Either Text Path
linearize = fmap Path . \case
  Stub    (Name name) -> Right $ UTF8.textShow name
  Content (CID cid)   -> Right $ textDisplay cid
  Directory [(tag, value)] ->
    case linearize value of
      Left  err         -> Left err
      Right (Path text) -> Right (fromKey tag <> "/" <> text)
  Directory _ -> Left "Not linear"
  where
    fromKey (Hash (CID cid))  = cid
    fromKey (Key (Name name)) = UTF8.textShow name
