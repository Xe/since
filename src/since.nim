import astar, asyncdispatch, dotenv,
       jester, json, logging, os, random,
       redis, strformat, strutils

import sincePkg/[base, pathing, redissave]

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
    try:
      let
        state = request.body.parseJson.to(State)
      var
        lastInfo: GameData
        target: CoordinatePair
        desc: string
        victim: string

      if state.turn != 0:
        lastInfo = (await getData(state.game.id, $(state.turn-1))).to(GameData)
        target = lastInfo.target
        desc = lastInfo.desc
        victim = lastInfo.victim
      else:
        let interm = state.findTarget
        target = interm.cp
        desc = interm.state
        victim = interm.victim

      case desc
      of "tail":
        target = state.you.tail
      of "hunting":
        var found = false
        for sn in state.board.snakes:
          if sn.id == victim:
            target = sn.head
            break
        if not found:
          let interm = state.findTarget
          target = interm.cp
          desc = interm.state
          victim = interm.victim
      else: discard

      let source = state.you.head

      if source == target or state.board.isDeadly(target):
        let interm = state.findTarget
        target = interm.cp
        desc = interm.state

      var myPath = state.findPath(source, target)
      while myPath.len == 0:
        target = state.board.randomSafeTile
        desc = "random-fallback"
        myPath = state.findPath(source, target)
      var
        myMove: string

      info fmt"{myPath}"
      if myPath.len >= 2:
        myMove = source -> myPath[1]
      else:
        debug fmt"can't find a path?"
        myMove = sample ["up", "left", "right", "down"]

      info fmt"game {state.game.id} turn {state.turn}: moving {myMove} to get to {target}"
      debug fmt"path: {myPath}"
      asyncCheck saveTurn(state, target, myMove, myPath, desc, victim)

      let ret = %* {
        "move": myMove
      }

      resp Http200, $ret, "application/json"
    except:
      info fmt"{getCurrentException().name}: {getCurrentExceptionMsg()}"
      info "random move"

      let ret = %* {
        "move": sample ["up", "left", "right", "down"]
      }

      resp Http200, $ret, "application/json"

  post "/end":
    let
      state = request.body.parseJson.to(State)
      didIWin = state.you.health > 0 and state.board.snakes.len == 1 and
                state.board.snakes[0].id == state.you.id

    info fmt"game {state.game.id} turn {state.turn}: win: {didIWin}"

    resp "OK"

  get "/inspect/@gameId":
    resp Http200, pretty await getGame(@"gameId"), "application/json"

  get "/inspect/@gameId/@turn":
    resp Http200, pretty await getData(@"gameId", @"turn"), "application/json"
