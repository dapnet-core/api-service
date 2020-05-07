#!/bin/sh

mix deps.get
export MIX_ENV=prod
mix deps.get
export SECRET_KEY_BASE=$(mix phx.gen.secret)
PORT=80 mix phx.server
