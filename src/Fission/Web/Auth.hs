{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators     #-}

module Fission.Web.Auth
  ( server
  , context
  , basic
  ) where

import RIO

import Servant

import Fission.Web.Server

server :: HasServer api '[BasicAuthCheck ByteString]
       => Proxy api
       -> cfg
       -> RIOServer cfg api
       -> Server api
server api cfg = hoistServerWithContext api context (toHandler cfg)

context :: Proxy (BasicAuthCheck ByteString ': '[])
context = Proxy

basic :: ByteString -> ByteString -> Context (BasicAuthCheck ByteString ': '[])
basic unOK pwOK = BasicAuthCheck check :. EmptyContext
  where
    check (BasicAuthData username password) =
      if (username == unOK) && (pwOK == password)
         then return $ Authorized username
         else return Unauthorized
