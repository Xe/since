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
