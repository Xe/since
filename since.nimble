# Package

version       = "0.1.0"
author        = "Christine Dodrill"
description   = ".i le mi nundambysince"
license       = "0BSD"
srcDir        = "src"
binDir        = "bin"
bin           = @["since"]

# Dependencies

requires "nim >= 0.20.2", "jester", "redis", "astar#head", "dotenv"

task test, "run tests":
  echo "running tests..."
  withDir "src/sincePkg":
    let testFiles = @["pathing"]

    for tf in testFiles:
      echo "testing " & tf
      exec "nim c --verbosity:0 -r " & tf
      rmFile tf.toExe
      echo "passed!"
