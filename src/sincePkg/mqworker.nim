import db_sqlite, json, net, os, waffle

import mqvals, pathing

let
  dbPath = "DATABASE_PATH".getenv
  db = open(dbPath, "", "", "")

db.exec sql"""
CREATE TABLE IF NOT EXISTS turns
  ( game_id TEXT
  , turn INTEGER
  , state TEXT
  , target_x INTEGER
  , target_y INTEGER
  , my_move TEXT
  , path TEXT
  , desc TEXT
  , victim TEXT
  );
"""

type
  Data = object
    state: State
    target: CoordinatePair
    path: Path
    myMove: string
    desc: string
    victim: string

proc saveTurn(c: StompClient, r: StompResponse) =
  let
    body = r.payload
    id = r["ack"]
    data = r.payload.parseJson.to Data
    s = data.state
    gameId = s.game.id
    turn = s.turn
    targetX = data.target.x
    targetY = data.target.y
    myMove = data.myMove
    path = data.path
    desc = data.path
    victim = data.victim

  try:
    discard db.insertId sql """
INSERT INTO turns
  (game_id, turn, state, target_x, target_y, my_move, path, desc, victim)
VALUES
  (?, ?, ?, ?, ?, ?, ?, ?, ?)""", gameId, turn, targetX, targetY, myMove, path, desc, victim
    c.ack(id)
  except:
    echo fmt"{getCurrentException().name}: {getCurrentExceptionMsg()}"
    c.nack(id)

var
  socket = newSocket()
  stomp = socket.newStompClient(getEnv "MQ_URL")

stomp.message_callback = saveTurn
stomp.subscribe gameTopic
stomp.waitForMessages

