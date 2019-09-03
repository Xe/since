import astar, hashes, logging, random, strformat
import battlesnake
export battlesnake

const
  good* = 1
  enemyThere* = 999
  selfThere* = 9999
  potentialEnemyMovement* = 50
  dangerousPlace* = 100

iterator neighbors*(s: State, p: CoordinatePair): CoordinatePair =
  for node in s.allNeighbors(p):
    s.yieldIfExistsAndSafe node

proc cost*(st: State, a, b: CoordinatePair): float =
  for s in st.board.snakes:
    for cp in s.body:
      if b == cp:
        result += enemyThere
        if s.id == st.you.id:
          result += selfThere
      for ne in st.neighbors(cp):
        if b == ne:
          result += potentialEnemyMovement
        for ne2 in st.neighbors(ne):
          if b == ne2:
            result += potentialEnemyMovement

  result += good

proc isEdge*(b: Board, p: CoordinatePair): bool =
  if p.x == 0 or p.y == 0 or p.x == b.width-1 or p.y == b.height-1:
    result = true
  else:
    result = false

proc heuristic*(s: State, node, goal: CoordinatePair): float =
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

  assert not (s.board.isDeadly result)

randomize()
proc randomSafeTile*(b: Board): CoordinatePair =
  result = newCP(rand(b.width), rand(b.height))
  if b.isDeadly(result) or b.isEdge(result):
    result = b.randomSafeTile

proc findSafeNeighbor(s: State, p: CoordinatePair): CoordinatePair =
  for ne in s.neighbors(p):
    return ne

proc findTail(s: State): CoordinatePair =
  s.findSafeNeighbor(s.you.tail)

proc findTarget*(s: State): tuple[cp: CoordinatePair, state: string,
    victim: string] =
  result = (newCP(-1, -1), "invalid", "")
  var
    totalLen = 0
    biggestLen = 0
  for snake in s.board.snakes:
    totalLen += snake.body.len
    if snake.body.len > biggestLen:
      biggestLen = snake.body.len
  let avgLen: float = totalLen / s.board.snakes.len

  template food() =
    debug fmt"seeking food (health: {s.you.health}, len: {s.you.body.len}, biggestLen: {biggestLen})"
    result = (findFood(s), "food", "")

  template hunt() =
    debug fmt"hunting (myLen: {s.you.body.len}, avgLen: {avgLen})"
    for snake in s.board.snakes:
      if snake.body.len < s.you.body.len:
        result = (s.findSafeNeighbor(snake.head), "hunting", snake.id)

  template randomTile() =
    result = (s.board.randomSafeTile, "random", "")

  template tail() =
    debug "chasing tail"
    result = (s.findTail, "tail", "")

  if s.board.food.len >= 1:
    debug "food found"
    if s.you.body.len < biggestLen or s.you.health <= 30: food()
    if s.turn == 0: food()
  elif s.you.body.len.float > avgLen: hunt()
  elif s.board.snakes.len == 2 and s.you.body.len == biggestLen: hunt()
  else:
    tail()

  if s.board.isDeadly(result.cp):
    debug fmt"chosen target {result} is deadly!"
    randomTile()

  if result.state == "invalid":
    case rand(2)
    of 1:
      tail()
    else:
      food()
  debug fmt"target: {result}"

proc findPath*(s: State, source, target: CoordinatePair): Path =
  result = newSeq[CoordinatePair]()
  for point in path[State, CoordinatePair, float](s, source, target):
    result.add point
  if result.len >= 2 and s.board.isDeadly result[1]:
    return s.findPath(source, s.board.randomSafeTile)

when isMainModule:
  import json, logging, os, unittest
  newConsoleLogger().addHandler

  const
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

  suite "findPath":
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
            #echo s.view(myPath)
            debug fmt"path: {myPath}"
            check:
              myPath.len != 0
              myPath.len >= 2
              not (s.board.isDeadly myPath[1])
