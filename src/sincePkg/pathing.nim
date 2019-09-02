import astar, hashes, logging, random, strformat

type
  Game* = object
    id*: string
  CoordinatePair* = object
    x*: int
    y*: int
  Path* = seq[CoordinatePair]
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

func `!=`* (a, b: CoordinatePair): bool =
  not (a == b)

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
      for ne in brd.neighbors(cp):
        if b == ne:
          return potentialEnemyMovement

  return good

proc isDeadly(b: Board, p: CoordinatePair): bool =
  for enemy in b.snakes:
    for seg in enemy.body:
      if seg == p:
        return true

  return false

proc isEdge(b: Board, p: CoordinatePair): bool =
  if p.x == 0 or p.y == 0 or p.x == b.width-1 or p.y == b.height-1:
    result = true
  else:
    result = false

proc heuristic*(b: Board, node, goal: CoordinatePair): float =
  if b.isDeadly node:
    return enemyThere
  chebyshev[CoordinatePair, float](node, goal)

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

  assert not (s.board.isDeadly result)

randomize()
proc randomSafeTile(b: Board): CoordinatePair =
  result = newCP(rand(b.width), rand(b.height))
  if b.isDeadly(result):
    result = b.randomSafeTile

proc findSafeNeighbor(s: State, p: CoordinatePair): CoordinatePair =
  for ne in s.board.neighbors(p):
    if not s.board.isDeadly(ne):
      return ne

proc findTail(s: State): CoordinatePair =
  s.findSafeNeighbor(s.you.tail)

proc findTarget*(s: State): CoordinatePair =
  result = newCP(-1, -1)
  var
    totalLen = 0
    biggestLen = 0
  for snake in s.board.snakes:
    totalLen += snake.body.len
    if snake.body.len > biggestLen:
      biggestLen = snake.body.len
  let avgLen: float = totalLen / s.board.snakes.len
  if s.board.food.len >= 1:
    if s.you.health <= 30 or s.you.body.len <= biggestLen:
      debug fmt"seeking food (health: {s.you.health}, len: {s.you.body.len}, biggestLen: {biggestLen})"
      result = findFood(s)
  if s.you.body.len.float > avgLen:
    debug fmt"hunting (myLen: {s.you.body.len}, avgLen: {avgLen})"
    for snake in s.board.snakes:
      if snake.body.len < s.you.body.len:
        result = s.findSafeNeighbor(snake.head)
  else:
    debug "chasing tail"
    result = s.findTail

  if s.board.isDeadly result:
    debug fmt"chosen target {result} is deadly!"
    return s.board.randomSafeTile

  debug fmt"target: {result}"

proc findPath*(s: State, source, target: CoordinatePair): Path =
  result = newSeq[CoordinatePair]()
  for point in path[Board, CoordinatePair, float](s.board, source, target):
    result.add point

when isMainModule:
  import json, logging, unittest
  newConsoleLogger().addHandler

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

  const
    findFoodData = slurp "./testdata/state_findfood.json"
    findTargetData = slurp "./testdata/state_findtarget.json"
    preventSelfKill = slurp "./testdata/state_prevent_self_kill.json"

  suite "board":
    test "randomSafeTile":
      let b = Board(
        height: 11,
        width: 11,
        food: newSeq[CoordinatePair](),
        snakes: @[
          Snake(
            id: "footest",
            name: "foo / bar",
            health: 9001,
            body: @[
              newCP(1, 1),
            ],
          ),
          Snake(
            id: "footest",
            name: "foo / bar",
            health: 9001,
            body: @[
              newCP(9, 9),
            ],
          ),
        ],
      )

      let deadlyPoints = @[newCP(1, 1), newCP(9, 9)]

      for _ in 1..100:
        let rp = b.randomSafeTile

        for dp in deadlyPoints:
          check(rp != dp)

  suite "targetFinding":
    template checkTargetIsntDeadly() =
      for snk in s.board.snakes:
        check:
          not (target in snk.body)
          target != newCP(0, 0)
          target != newCP(-1, -1)

    template runTest(s: State) =
      discard

    test "findFood":
      let
        ss = findFoodData.parseJson.to(seq[State])
      for s in ss:
        let
          target = s.findFood
        check target in s.board.food
        checkTargetIsntDeadly()

    test "findTail":
      let
        s = findTargetData.parseJson.to(State)
        target = s.findTail
      checkTargetIsntDeadly()

    test "findTarget":
      let
        s = findTargetData.parseJson.to(State)
        target = s.findTarget
      checkTargetIsntDeadly()

  suite "findPath":
    test "findFood":
      let ss = findFoodData.parseJson.to(seq[State])
      for s in ss:
        let
          source = s.you.head
          target = s.findTarget
          myPath = s.findPath(source, target)
        check:
          myPath.len >= 2
          not (s.board.isDeadly myPath[1])

    test "dontKillSelf":
      let ss = preventSelfKill.parseJson.to(seq[State])
      for s in ss:
        let
          source = s.you.head
          target = s.findTarget
          myPath = s.findPath(source, target)
        check:
          myPath.len >= 2
          not (s.board.isDeadly myPath[1])

