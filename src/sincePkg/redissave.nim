import algorithm, asyncdispatch, json, os, redis, strformat, strutils
import pathing, redisurl

type GameData* = object
  state*: State
  target*: CoordinatePair
  myMove*: string
  path*: Path
  desc*: string

proc cmp*(a, b: GameData): int =
  return cmp[int](a.state.turn, b.state.turn)

var redisClient: AsyncRedis

proc init*(url: string) {.async.} =
  let creds = redisurl.parse url
  redisClient = await openAsync(creds.host, creds.port)
  if creds.password != "":
    waitFor redisClient.auth creds.password

  proc pingRedis() {.async.} =
    while true:
      await sleepAsync 5_000
      discard await redisClient.ping

  asyncCheck pingRedis()

proc createKey(gameId, turn: string): string =
  fmt"{gameId}:{turn}"

proc createKey(s: State): string =
  createKey(s.game.id, $s.turn)

proc compareKey(a, b: string): int =
  let
    aSp = a.split(":")
    bSp = b.split(":")

  return cmp[int](aSp[1].parseInt, bSp[1].parseInt)

proc saveTurn*(s: State, target: CoordinatePair, myMove: string, path: Path, desc: string) {.async.} =
  let toWrite = %* {
    "state": s,
    "target": target,
    "path": path,
    "myMove": myMove,
    "desc": desc
  }

  await redisClient.setk(s.createKey, $toWrite)

proc getGame*(gameId: string): Future[JsonNode] {.async.} =
  result = newJArray()

  var keys = await redisClient.keys(fmt"{gameId}:*")
  keys.sort compareKey
  for key in keys:
    let data = await redisClient.get(key)
    result.add data.parseJson

proc getData*(gameId, turn: string): Future[JsonNode] {.async.} =
  let data = await redisClient.get(createKey(gameId, turn))
  result = data.parseJson
