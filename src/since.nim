import astar, asyncdispatch, dotenv,
       hashes, jester, json, os, strformat, strutils

try: initDotEnv().overload
except: discard

type
  Game* = object
    id*: string
  CoordinatePair* = object
    x*: int
    y*: int
  Snake* = object
    id*: string
    name*: string
    health*: int
    body*: seq[CoordinatePair]
  Board* = object
    height*: int
    width*: int
    food*: seq[CoordinatePair]
    snakes*: seq[Snake]
  State* = object
    game*: Game
    turn*: int
    board*: Board
    you*: Snake

const
  good = 1
  enemyThere = 999
  potentialEnemyMovement = 50

proc newCP*(x, y: int): CoordinatePair =
  CoordinatePair(
    x: x,
    y: y,
  )

func `==`*(a, b: CoordinatePair): bool =
  a.x == b.x and a.y == b.y

func `$`*(p: CoordinatePair): string =
  fmt"({p.x}, {p.y})"

func `->`*(l, r: CoordinatePair): string =
  if l.x < r.x:
    return "right"
  if l.x > r.x:
    return "left"
  if l.y < r.y:
    return "up"
  if l.y > r.y:
    return "down"

  assert(false)

func head*(s: Snake): CoordinatePair =
  s.body[0]

func tail*(s: Snake): CoordinatePair =
  s.body[s.len - 1]

template yieldIfExists(b: Board, p: CoordinatePair) =
  let exists =
    p.x >= 0 and p.x < b.width and
    p.y >= 0 and p.y < b.height
  if exists:
    yield p

iterator neighbors*(b: Board, p: CoordinatePair): CoordinatePair =
  b.yieldIfExists newCP(p.x - 1, p.y)
  b.yieldIfExists newCP(p.x + 1, p.y)
  b.yieldIfExists newCP(p.x, p.y - 1)
  b.yieldIfExists newCP(p.x, p.y + 1)

proc cost*(brd: Board, a, b: CoordinatePair): float =
  for s in brd.snakes:
    for cp in s.body:
      if b == cp:
        return enemyThere

  return good

proc heuristic*(b: Board, node, goal: CoordinatePair): float =
  manhattan[CoordinatePair, float](node, goal)

proc findTarget*(s: State): CoordinatePair =
  if s.you.health <= 30:
    var foods = newSeq[tuple [cost: float, point: CoordinatePair]]()
    for cp in s.board.food:
      foods.add(
        (
          manhattan[CoordinatePair, float](s.you.head(), cp),
          cp
        )
      )
    var lowest = 999999.9999 # XXX(Xe): HACK
    for data in foods:
      if data.cost < lowest:
        lowest = data.cost
        result = data.point
    return result

  s.you.tail

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

