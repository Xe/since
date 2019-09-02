import hashes, strformat

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

template yieldIfExists*(s: State, p: CoordinatePair) =
  let exists =
    p.x >= 0 and p.x < s.board.width and
    p.y >= 0 and p.y < s.board.height
  if exists:
    yield p

proc view*(s: State, p: Path): string =
  var grid = newSeq[seq[string]](s.board.height)
  for i in 0 .. < s.board.height:
    grid[i] = newSeq[string](s.board.width)

  for elem in p:
    grid[elem.y][elem.x] = "p"

  for sn in s.board.snakes:
    for seg in sn.body:
      grid[seg.y][seg.x] = $sn.name[0]
    grid[sn.head.y][sn.head.x] = "H"

  for seg in s.you.body:
    grid[seg.y][seg.x] = "Y"
  grid[s.you.head.x][s.you.head.x] = "y"

  for food in s.board.food:
    grid[food.y][food.x] = "F"

  for row in grid:
    for column in row:
      case column
      of "":
        result &= " "
      else:
        result &= column
    result &= "\n"
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

      for p in pairs:
        let intermediate = p.a -> p.b
        check intermediate == p.s
