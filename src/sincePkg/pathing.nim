import astar, hashes, logging, random, strformat
import battlesnake
export battlesnake

const
  good* = 1
  enemyThere* = 999
  selfThere* = 9999
  potentialEnemyMovement* = 50
  dangerousPlace* = 100

iterator neighbors*(b: State, p: CoordinatePair): CoordinatePair =
  b.yieldIfExists newCP(p.x - 1, p.y)
  b.yieldIfExists newCP(p.x + 1, p.y)
  b.yieldIfExists newCP(p.x, p.y - 1)
  b.yieldIfExists newCP(p.x, p.y + 1)

proc cost*(st: State, a, b: CoordinatePair): float =
  for s in st.board.snakes:
    for cp in s.body:
      if b == cp:
        return enemyThere
      if s.id == st.you.id:
        continue
      for ne in st.neighbors(cp):
        if b == ne:
          return potentialEnemyMovement

  return good

proc isDeadly*(b: Board, p: CoordinatePair): bool =
  for enemy in b.snakes:
    for seg in enemy.body:
      if seg == p:
        return true

  return false

proc isDangerous*(s: State, p: CoordinatePair): bool =
  for loc in s.neighbors p:
    for sn in s.board.snakes:
      if loc == sn.head:
        return true

  false

proc isEdge*(b: Board, p: CoordinatePair): bool =
  if p.x == 0 or p.y == 0 or p.x == b.width-1 or p.y == b.height-1:
    result = true
  else:
    result = false

proc heuristic*(s: State, node, goal: CoordinatePair): float =
  if node in s.you.body:
    return selfThere
  if s.isDangerous node:
    return dangerousPlace
  if s.board.isDeadly node:
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
  if b.isDeadly(result) or b.isEdge(result):
    result = b.randomSafeTile

proc findSafeNeighbor(s: State, p: CoordinatePair): CoordinatePair =
  for ne in s.neighbors(p):
    if not s.board.isDeadly(ne):
      return ne

proc findTail(s: State): CoordinatePair =
  s.findSafeNeighbor(s.you.tail)

proc findTarget*(s: State): tuple[cp: CoordinatePair, state: string] =
  result = (newCP(-1, -1), "invalid")
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
      result = (findFood(s), "food")
  elif s.you.body.len.float > avgLen:
    debug fmt"hunting (myLen: {s.you.body.len}, avgLen: {avgLen})"
    for snake in s.board.snakes:
      if snake.body.len < s.you.body.len:
        result = (s.findSafeNeighbor(snake.head), "hunting")
  else:
    debug "chasing tail"
    result = (s.findTail, "tail")

  if s.board.isDeadly(result.cp):
    debug fmt"chosen target {result} is deadly!"
    return (s.board.randomSafeTile, "random")

  debug fmt"target: {result}"

proc findPath*(s: State, source, target: CoordinatePair): Path =
  result = newSeq[CoordinatePair]()
  for point in path[State, CoordinatePair, float](s, source, target):
    result.add point
  if result.len >= 2 and s.board.isDeadly result[1]:
    return s.findPath(source, s.board.randomSafeTile)

when isMainModule:
  import json, logging, os, unittest
  #newConsoleLogger().addHandler

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
        check:
          not b.isDeadly(rp)
          not b.isEdge(rp)

  suite "targetFinding":
    template checkTargetIsntDeadly() =
      for snk in s.board.snakes:
        check:
          not (target in snk.body)
          target != newCP(0, 0)
          target != newCP(-1, -1)

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
        target = s.findTarget.cp
      checkTargetIsntDeadly()

  suite "findPath":
    test "findFood":
      let ss = findFoodData.parseJson.to(seq[State])
      for s in ss:
        let
          source = s.you.head
          target = s.findTarget
          myPath = s.findPath(source, target.cp)
        debug fmt"{target} -> {myPath}"
        check:
          myPath.len >= 2
          not (s.board.isDeadly myPath[1])

    test "dontKillSelf":
      let ss = preventSelfKill.parseJson.to(seq[State])
      for s in ss:
        let
          source = s.you.head
          target = s.findTarget
          myPath = s.findPath(source, target.cp)
        if myPath.len != 0:
          check:
            myPath.len >= 2
            not (s.board.isDeadly myPath[1])

  suite "against random games":
    type GameInfo = object
      state: State
      target: CoordinatePair
      path: Path
      myMove: string
    for fName in walkFiles("./testdata/games/*"):
      test fName:
        let
          data = fName.readFile
          gis = data.parseJson.to(seq[GameInfo])
        for gi in gis:
          test fmt"{gi.state.game.id} turn {gi.state.turn}":
            let
              s = gi.state
              source = s.you.head
              target = s.findTarget
              myPath = s.findPath(source, target.cp)
            echo s.view(myPath)
            debug fmt"path: {myPath}"
            if myPath.len > 0:
              check:
                myPath.len >= 2
                not (s.board.isDeadly myPath[1])
