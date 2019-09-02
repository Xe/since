import astar, hashes, logging, strformat

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
  good* = 1
  enemyThere* = 999
  potentialEnemyMovement* = 50

proc newCP*(x, y: int): CoordinatePair =
  CoordinatePair(
    x: x,
    y: y,
  )

func `==`*(a, b: CoordinatePair): bool =
  a.x == b.x and a.y == b.y

func `$`*(p: CoordinatePair): string =
  fmt"({p.x}, {p.y})"

func hash*(p: CoordinatePair): Hash =
  var h: Hash = 0
  h = h !& hash(p.x)
  h = h !& hash(p.y)
  result = !$h

func `->`*(l, r: CoordinatePair): string =
  if l.x < r.x:
    return "right"
  if l.x > r.x:
    return "left"
  if l.y > r.y:
    return "up"
  if l.y < r.y:
    return "down"

  assert(false)

func head*(s: Snake): CoordinatePair =
  s.body[0]

func tail*(s: Snake): CoordinatePair =
  s.body[s.body.len - 1]

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

proc isDeadly(b: Board, p: CoordinatePair): bool =
  for enemy in b.snakes:
    for seg in enemy.body:
      if seg == p:
        return true

  return false

proc heuristic*(b: Board, node, goal: CoordinatePair): float =
  manhattan[CoordinatePair, float](node, goal)

proc findFood(s: State): CoordinatePair =
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

proc findTarget*(s: State): CoordinatePair =
  var biggestLen = 0
  for snake in board.snakes:
    if snake.body.len > biggestLen:
      biggestLen = snake.body.len
  if s.you.health <= 30 or s.you.body.len <= biggestLen:
    debug "seeking food"
    return findFood(s)
  debug "chasing tail"
  result = s.you.tail
  for snake in board.snakes:
    if s.you.id == snake.id:
      continue
    for next in neighbors(b, snake.head):
      if result == next:
        return findFood(s)

when isMainModule:
  import unittest

  suite "coordinates":
    test "equality":
      assert newCP(1, 1) == newCP(1, 1)
    test "toString":
      assert $newCP(1, 1) == "(1, 1)"
    test "directionality":
      type Case = tuple[a, b: CoordinatePair, s: string]
      let pairs: seq[Case] = @[
        (newCP(1, 1), newCP(2, 1), "right"),
        (newCP(1, 1), newCP(0, 1), "left"),
        (newCP(1, 1), newCP(1, 0), "up"),
        (newCP(1, 1), newCP(1, 2), "down")
      ]

      var failed = false

      for p in pairs:
        let intermediate = p.a -> p.b
        if intermediate != p.s:
          echo fmt"wanted: {p.a} -> {p.b} == {p.s}, got: {intermediate}"
          failed = true

      assert not failed
