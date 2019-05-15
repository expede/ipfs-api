{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Fission.Web.Ping where

import RIO
import Servant

import Fission.Web.Server

type API = Get '[JSON, PlainText] Text

api :: Proxy API
api = Proxy

server :: RIOServer cfg API
server = return "pong"
