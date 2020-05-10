#!/bin/sh

mix deps.get
PORT=80 mix phx.server
