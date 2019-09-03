# Package

version = "0.1.0"
author = "Christine Dodrill"
description = ".i le mi nundambysince"
license = "0BSD"
srcDir = "src"
binDir = "bin"
bin = @["since"]

let testFiles = @[
  "base",
  "battlesnake",
  "pathing",
  "redissave",
  "redisurl",
  "targeting",
]

# Dependencies

requires "nim >= 0.20.2", "jester", "redis",
         "astar#head", "dotenv", "cligen", "nimbox"

task catlu, "ko zbasu la catlu":
  withDir "src/sincePkg":
    exec "nim --hints:off --verbosity:0 c -o:../../bin/catlu catlu"

task setupremote, "set up dokku remote":
  exec "git remote add dokku dokku@minipaas.xeserv.us:since"

task test, "run tests":
  echo "running tests..."
  withDir "src/sincePkg":
    for tf in testFiles:
      exec "nim c --hints:off --verbosity:0 -r " & tf
      rmFile tf.toExe
