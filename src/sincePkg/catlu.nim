import json, nimbox, strformat, strutils
import battlesnake, redissave, pathing

const inpFile = "./testdata/games/b479d1da-f9e9-4731-819d-9eaec7960d08"

proc view(nb: NimBox, gd: GameData, autoplay: bool) =
  for y in countup(0, gd.state.board.height):
    for x in countup(0, gd.state.board.width):
      let cp = newCP(x, y)
      var
        fg = clrDefault
        bg = clrDefault
        sigil = " "

      if cp == gd.target:
        bg = clrRed
        sigil = "%"
      for sn in gd.state.board.snakes:
        for seg in sn.body:
          if cp == seg:
            if gd.state.you.id == sn.id:
              fg = clrGreen
            else:
              fg = clrRed
            sigil = ($sn.name[0]).toUpperAscii
          if cp == sn.head:
            sigil = ($sn.name[0]).toLowerAscii

      for elem in gd.path:
        if cp == elem:
          bg = clrWhite

      for elem in gd.state.board.food:
        if cp == elem:
          fg = clrBlue
          sigil = "@"

      nb.print(x, y, sigil, fg, bg)
  nb.print(15, 0, fmt"game: {gd.state.game.id}")
  nb.print(15, 1, fmt"turn: {gd.state.turn}")
  nb.print(15, 2, fmt"desc: {gd.desc}")
  nb.print(15, 3, fmt"targ: {gd.target}")
  nb.print(15, 4, fmt"leng: {gd.state.you.body.len}")
  nb.print(15, 5, "---")
  nb.print(15, 6, "snakes:")

  var ln = 7

  for sn in gd.state.board.snakes:
    nb.print(15, ln, fmt"name: {sn.name[0]}, len: {sn.body.len}, health: {sn.health}")
    ln += 1

  nb.print(0, ln+1, fmt"autoplay: {autoplay}")
  nb.print(0, ln+2, "Controls:")
  nb.print(0, ln+3, "Left:  go back a turn")
  nb.print(0, ln+4, "Right: go foward a turn")
  nb.print(0, ln+5, "Home:  go to the first turn")
  nb.print(0, ln+6, "Esc/q: exit")

proc showGame(inpFile: string, startTurn = 0, autoplay = false, delay = 250) =
  let gds = inpFile.readFile.parseJson.to(seq[GameData])
  var nb = newNimbox()
  defer: nb.shutdown()
  var
    evt: Event
    turn = startTurn
    doingAutoplay = autoplay

  while true:
    nb.clear()
    nb.view(gds[turn], doingAutoplay)
    nb.present()

    evt = nb.peekEvent(delay)
    case evt.kind
    of EventType.Key:
      if Modifier.Ctrl in evt.mods and evt.ch == 'c':
        break
      case evt.sym
      of Symbol.Escape:
        break
      of Symbol.Left:
        if turn != 0:
          turn -= 1
      of Symbol.Right:
        if turn != gds.len-1:
          turn += 1
      of Symbol.Home:
        turn = 0
      of Symbol.End:
        turn = gds.len-1
      of Symbol.Space:
        doingAutoplay = not doingAutoplay
      else: discard

      case evt.ch
      of 'q':
        break
      else: discard
    else: discard

    if doingAutoplay:
      if turn != gds.len-1:
        turn += 1
      else:
        doingAutoplay = false

when isMainModule:
  import cligen
  dispatch showGame
