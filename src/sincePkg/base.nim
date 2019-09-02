import dotenv, logging, os

try: initDotEnv().overload
except: discard

var l: ConsoleLogger
case getEnv "LOG_LEVEL"
of "INFO":
  l = newConsoleLogger(levelThreshold = lvlInfo)
else:
  l = newConsoleLogger()
  l.addHandler
