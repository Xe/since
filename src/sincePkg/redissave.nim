import asyncdispatch, json, os, redis, strformat
import pathing, redisurl

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

func createKey(s: State): string =
  createKey(s.game.id, $s.turn)

func createKey(gameId, turn: string): string =
  fmt"{gameId}:{turn}"

proc saveTurn*(s: State, target: CoordinatePair, myMove: string) {.async.} =
  let toWrite = %* {
    "state": s,
    "target": target,
    "myMove": myMove
  }

  await redisClient.setk(s.createKey, $toWrite)

proc getData*(gameId, turn: string): JsonNode {.async.}
  let data = await redisClient.get(createKey gameId, turn)
  result = data.parseJson
