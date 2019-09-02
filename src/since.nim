import astar, asyncdispatch, dotenv,
       jester, json, logging, os, redis,
       strformat, strutils

import sincePkg/[pathing, redissave]

try: initDotEnv().overload
except: discard
newConsoleLogger().addHandler

waitFor redissave.init getEnv "REDIS_URL"
info "redis client initialized"

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
    const
      snakeColor = "#FFD600"
      headType = "beluga"
      tailType = "skinny"
    let
      state = request.body.parseJson.to(State)
      ret = %* {
        "color": snakeColor,
        "headType": headType,
        "tailType": tailType
      }
    info fmt"game {state.game.id}: starting"
    resp Http200, $ret, "application/json"

  post "/move":
    let
      state = request.body.parseJson.to(State)
      source = state.you.head()
      target = state.findTarget
    var
      myPath = newSeq[CoordinatePair]()
    for point in path[Board, CoordinatePair, float](state.board, source, target):
      myPath.add point
    let myMove = source -> myPath[1]

    info fmt"game {state.game.id} turn {state.turn}: moving {myMove}"
    debug fmt"path: {myPath}"
    asyncCheck saveTurn(state, target, myMove)

    let ret = %* {
      "move": myMove
    }

    resp Http200, $ret, "application/json"

  post "/end":
    let
      state = request.body.parseJson.to(State)
      didIWin = state.you.health > 0 and state.board.snakes.len == 1 and
                state.board.snakes[0].id == state.you.id

    info fmt"game {state.game.id} turn {state.turn}: win: {didIWin}"

    resp "OK"

