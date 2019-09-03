import astar, strutils
import battlesnake
import vendor/fsm

type
  State* {.pure.} = enum
    Init = "init",
    Food = "food",
    Hunt = "hunt",
    Tail = "tail"

  Event* {.pure.} = enum
    Init = "init",
    Hungry = "hungry",
    Eaten = "eaten",
    Growth = "growth",
    HuntTargetFound = "hunt_target_found",
    TargetGone = "target_gone",
    NoFood = "no_food",
    UnsafeTarget = "unsafe_target",
    TargetTooLong = "target_too_long"

  StateMachine* = Machine[State, Event]
  Step* = object
    event*: Event
    case state*: State
    of State.Init: discard
    of State.Food, State.Tail:
      target*: CoordinatePair
    of State.Hunt:
      victim*: Snake

proc initMachine*(desc: string): StateMachine =
  let st = parseEnum[State](desc, State.Init)
  result = newMachine[State, Event](st)

  # States:
  #[
    digraph G {
      init [label = "State.Init", shape = Mdiamond];
      food [label = "State.Food"];
      hunt [label = "State.Hunt"];
      tail [label = "State.Tail"];

      init -> food [label = "Event.Init"];
      food -> tail [label = "Event.Eaten"];
      food -> food [label = "Event.TargetGone"];
      food -> tail [label = "Event.NoFood"];
      food -> hunt [label = "Event.HuntTargetFound"];
      food -> tail [label = "Event.UnsafeTarget"];
      hunt -> tail [label = "Event.TargetGone"];
      hunt -> tail [label = "Event.UnsafeTarget"];
      hunt -> food [label = "Event.TargetTooLong"];
      hunt -> food [label = "Event.Hungry"];
      tail -> food [label = "Event.Growth"];
      tail -> food [label = "Event.Hungry"];
      tail -> hunt [label = "Event.HuntTargetFound"];
    }
  ]#

  result.addTransition(State.Init, Event.Init, State.Food)

  result.addTransition(State.Food, Event.Eaten, State.Tail)
  result.addTransition(State.Food, Event.TargetGone, State.Food)
  result.addTransition(State.Food, Event.NoFood, State.Tail)
  result.addTransition(State.Food, Event.HuntTargetFound, State.Hunt)
  result.addTransition(State.Food, Event.UnsafeTarget, State.Tail)

  result.addTransition(State.Hunt, Event.TargetGone, State.Tail)
  result.addTransition(State.Hunt, Event.UnsafeTarget, State.Tail)
  result.addTransition(State.Hunt, Event.TargetTooLong, State.Food)
  result.addTransition(State.Hunt, Event.Hungry, State.Food)

  result.addTransition(State.Tail, Event.Growth, State.Food)
  result.addTransition(State.Tail, Event.Hungry, State.Food)
  result.addTransition(State.Tail, Event.HuntTargetFound, State.Hunt)

proc mh(a, b: CoordinatePair): float = manhattan[CoordinatePair, float](a, b)

iterator findFood(s: battlesnake.State): tuple[cost: float, target: CoordinatePair] =
  for f in s.board.food:
    let cost = mh(s.you.head, f)
    yield (cost, f)

iterator findHunt(s: battlesnake.State): tuple[cost: float, victim: Snake, lenDiff: int] =
  for sn in s.board.snakes:
    if sn.body.len < s.you.body.len:
      let
        cost = mh(s.you.head, sn.head)
        lenDiff = s.you.body.len - sn.body.len
      yield (cost, sn, lenDiff)

proc isHungry(sn: Snake): bool =
  sn.health >= 20

proc getEvent*(sm: StateMachine, s: battlesnake.State, last: Step): Step =
  template step(e: Event) =
    result.event = e
    sm.process(e)
    result.state = sm.getCurrentState

  template getAFood() =
    var lowestCost = 999999.9999 # XXX(Xe): HACK
    for f in s.findFood:
      if f.cost < lowestCost:
        lowestCost = f.cost
        result.target = f.target

  proc getHuntTarget(): tuple[cost: float, victim: Snake, lenDiff: int, found: bool] =
    result.cost = 999999.9999 # XXX(Xe): HACK
    for t in s.findHunt:
      if t.lenDiff > result.lenDiff and t.cost < result.cost:
        result.cost = t.cost
        result.lenDiff = t.lenDiff
        result.victim = t.victim
        result.found = true

  template getTail() =
    result.target = s.you.tail
    return result

  template actOnHunger() =
    if s.you.isHungry:
      step(Event.Hungry)
      getAFood()
      return result

  template actOnHuntTarget() =
    let ht = getHuntTarget()
    if ht.found:
      if mh(s.you.head, ht.victim.head) < mh(s.you.head, last.target):
        step(Event.HuntTargetFound)
        result.victim = ht.victim
        return result

  case sm.getCurrentState
  of State.Init:
    step(Event.Init)
    getAFood()
    return
  of State.Food:
    actOnHuntTarget()

    if s.you.head == last.target:
      step(Event.Eaten)
      getTail()
    elif s.isDangerous last.target:
      step(Event.UnsafeTarget)
      getTail()

  of State.Hunt:
    actOnHunger()

    var foundLastVictim = false
    for sn in s.board.snakes:
      if sn.id == last.victim.id:
        foundLastVictim = true

    if not foundLastVictim:
      step(Event.TargetGone)
      getTail()

    # If it's hunt-dangerous, step(Event.UnsafeTarget); getTail()

    if last.victim.body.len >= s.you.body.len:
      step(Event.TargetTooLong)
      getTail()

  of State.Tail:
    actOnHunger()
    actOnHuntTarget()

    var
      totalLen = 0
    for sn in s.board.snakes:
      totalLen += sn.body.len
    let avgLen: float = totalLen / s.board.snakes.len
    if s.you.body.len.float < avgLen:
      step(Event.Growth)
      getAFood()
      return result

  result = last
