import dotenv, jester, logging, os, strutils
import jester/private/utils # XXX(Xe): needed for Settings type
export Settings

try: initDotEnv().overload
except: discard

var l: ConsoleLogger
case getEnv "LOG_LEVEL"
of "INFO":
  l = newConsoleLogger(levelThreshold = lvlInfo)
else:
  l = newConsoleLogger()
  l.addHandler

proc jesterSettings*(): Settings =
  newSettings(
    bindAddr = getEnv "BIND_ADDR",
    port = getEnv("PORT").parseInt.Port,
  )
