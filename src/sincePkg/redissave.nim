import asyncdispatch, json, os, redis, strformat
import pathing, redisurl

type GameData* = object
  state: State
  target: CoordinatePair
  myMove: string
  path: Path

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

proc saveTurn*(s: State, target: CoordinatePair, myMove: string, path: Path) {.async.} =
  let toWrite = %* {
    "state": s,
    "target": target,
    "path": path,
    "myMove": myMove
  }

  await redisClient.setk(s.createKey, $toWrite)

proc getGame*(gameId: string): Future[JsonNode] {.async.} =
  result = newJArray()

  let keys = (await redisClient.keys(fmt"{gameId}:*")).sort
  for key in keys:
    let data = await redisClient.get(key)
    result.add data.parseJson

proc getData*(gameId, turn: string): Future[JsonNode] {.async.} =
  let data = await redisClient.get(createKey(gameId, turn))
  result = data.parseJson
