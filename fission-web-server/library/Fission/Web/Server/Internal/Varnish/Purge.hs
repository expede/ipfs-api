module Fission.Web.Server.Internal.Varnish.Purge
  ( purge
  , purgeMany
  , module Fission.Web.Server.Internal.Varnish.Purge.Error
  , module Fission.Web.Server.Internal.Varnish.Purge.Types
  ) where

import           Network.HTTP.Req
import           RIO.NonEmpty

import           Fission.Prelude

import           Fission.URL.Types
import           Fission.Web.Server.Error.Class

import qualified Fission.Web.Server.Internal.Varnish.Purge.Error as Varnish

-- Reexports

import           Fission.Web.Server.Internal.Varnish.Purge.Error
import           Fission.Web.Server.Internal.Varnish.Purge.Types

-- | Purge a URL from the Varnish cache
-- Varnish docs: https://docs.nginx.com/nginx/admin-guide/content-cache/content-caching/#purge_request
purge :: MonadHttp m => URL -> m (Either Varnish.Error ())
purge url = do
  resp <- req PURGE (https $ textDisplay url) NoReqBody ignoreResponse mempty
  let status = responseStatusCode resp
  if status >= 400
    then return . Left . Varnish.Error $ toServerError status
    else return $ Right ()

purgeMany :: forall m . MonadHttp m => [URL] -> m (Either Varnish.BatchErrors ())
purgeMany urls =
  foldM mAcc (Right ()) urls
  where
    mAcc :: Either Varnish.BatchErrors () -> URL -> m (Either Varnish.BatchErrors ())
    mAcc acc url =
      purge url >>= \case
        Right () ->
          return acc

        Left (Varnish.Error err) ->
          return . Left $ BatchErrors case acc of
            Right ()                      -> [err]
            Left (Varnish.BatchErrors errs) -> (err `cons` errs)