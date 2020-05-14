#!/bin/sh

mix deps.get
mix ecto.create
mix ecto.migrate
PORT=80 mix phx.server
