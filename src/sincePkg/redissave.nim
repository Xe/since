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
  fmt"{s.game.id}:{s.turn}"

proc saveTurn*(s: State, target: CoordinatePair, myMove: string) {.async.} =
  let toWrite = %* {
    "state": s,
    "target": target,
    "myMove": myMove
  }

  await redisClient.setk(s.createKey, $toWrite)
