import json, nimbox, os, strformat, strutils
import battlesnake, redissave, pathing

proc view(nb: NimBox, gd: GameData, autoplay: bool) =
  for y in countup(0, gd.state.board.height):
    for x in countup(0, gd.state.board.width):
      let cp = newCP(x, y)
      var
        fg = 0
        bg = 0
        sigil = " "

      for sn in gd.state.board.snakes:
        for seg in sn.body:
          if cp == seg:
            fg = sn.name[0].int
            sigil = ($sn.name[0]).toUpperAscii
          if cp == sn.head:
            sigil = ($sn.name[0]).toLowerAscii

      for elem in gd.path:
        if cp == elem:
          bg = 244

      if cp == gd.target:
        bg = 52
        fg = 58

      for elem in gd.state.board.food:
        if cp == elem:
          fg = 195
          sigil = "@"

      nb.print(x, y, sigil, fg, bg)

  nb.print(15, 0, fmt"game: {gd.state.game.id}")
  nb.print(15, 1, fmt"turn: {gd.state.turn}")
  nb.print(15, 2, fmt"desc: {gd.desc}")
  nb.print(15, 3, fmt"targ: {gd.target}")
  nb.print(15, 4, fmt"leng: {gd.state.you.body.len}")
  nb.print(15, 5, "---")
  nb.print(15, 6, "snakes:")

  var ln = 8

  for sn in gd.state.board.snakes:
    var bg = 0
    if gd.victim == sn.id:
      bg = 232
    nb.print(15, ln, fmt"name: {sn.name[0]}, len: {sn.body.len}, health: {sn.health}",
        sn.name[0].int, bg)
    ln += 1

  ln = 13

  nb.print(0, ln+1, fmt"autoplay: {autoplay}")
  nb.print(0, ln+2, "Controls:")
  nb.print(0, ln+3, "Left:  go back a turn")
  nb.print(0, ln+4, "Right: go foward a turn")
  nb.print(0, ln+5, "Home:  go to the first turn")
  nb.print(0, ln+6, "Esc/q: exit")
  nb.print(0, ln+7, "Space: toggle autoplay")

proc catlu(inpFile: string, startTurn = 0, autoplay = false, delay = 250,
    thenExit = false) =
  let gds = inpFile.readFile.parseJson.to(seq[GameData])
  var nb = newNimbox()
  defer: nb.shutdown()
  nb.outputMode = out256
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
        if thenExit:
          sleep 2
          break

when isMainModule:
  import cligen
  dispatch catlu
