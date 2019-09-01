import astar, asyncdispatch, dotenv,
       hashes, jester, json, os, strformat, strutils

import sincePkg/[pathing]

try: initDotEnv().overload
except: discard

settings:
  bindAddr = getEnv "BIND_ADDR"
  port = getEnv("PORT").parseInt.Port

routes:
  get "/":
    let version = getEnv "GIT_REV"
    resp fmt"""<p>Battlesnake documentation can be found at <a href="https://docs.battlesnake.io">https://docs.battlesnake.io</a>.</p><p>version: {version}"""

  post "/ping":
    resp "OK"

  post "/start":
    let
      state = request.body.parseJson.to(State)
      ret = %* {
        "color": "#FFD600",
        "headType": "beluga",
        "tailType": "skinny"
      }
    resp Http200, $ret, "application/json"

  post "/move":
    let
      state = request.body.parseJson.to(State)
      source = state.you.head()
      target = state.findTarget
    var
      myPath = newSeq[CoordinatePair]()
    for point in path[Board, CoordinatePair, float](state.board, source, target):
      mypath.add point

    let ret = %* {
      "move": source -> target
    }

    resp Http200, $ret, "application/json"

