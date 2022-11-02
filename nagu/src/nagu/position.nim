## src/nagu/position.nim defines the Position type and procedures related to its.

from std/sugar import `->`, `=>`
from std/strformat import `&`
from std/math import almostEqual

type
  PositionObj = object
    x, y, z: float32
  
  Position* = ref PositionObj
    ## The Position type representations 3D coordinates.
    ## It has x, y and z members, but they are not published.
    ## You should call the `coord` function, if you get coordinates information of a position.

func init* (_: typedesc[Position], x, y, z: float32): Position =
  ## Initializes a Position object by `x`, `y` and `z`.
  result = Position(x: x, y: y, z: z)

func coord* (pos: Position): tuple[x, y, z: float32] =
  ## Gets coordinates information of a Position object.
  runnableExamples:
    doAssert Position.init(1, 2, 3).coord == (1.0f, 2.0f, 3.0f)
  result = (pos.x, pos.y, pos.z)

func `$`* (pos: Position): string =
  ## Converts a Position object into string.
  runnableExamples:
    doAssert $Position.init(1, 2, 3) == "(x: 1.0, y: 2.0, z: 3.0)"
  result = &"(x: {pos.x}, y: {pos.y}, z: {pos.z})"

func map* (pos: Position, fn: float32 -> float32): Position =
  ## Applies `fn` to each element of `pos`.
  runnableExamples:
    func square (n: float32): float32 = n * n
    doAssert Position.init(1, 2, 3).map(square) == Position.init(1, 4, 9)
  result = Position(
    x: fn(pos.x),
    y: fn(pos.y),
    z: fn(pos.z)
  )

func map* (pos1, pos2: Position, fn: (float32, float32) -> float32): Position =
  ## Applies `fn` to each element of `pos`.
  runnableExamples:
    func max (n, m: float32): float32 =
      result = if n >= m: n
               else: m
    let
      position1 = Position.init(1, 4, 9)
      position2 = Position.init(2, 4, 6)
    doAssert map(position1, position2, max) == Position.init(2, 4, 9)
  result = Position(
    x: fn(pos1.x, pos2.x),
    y: fn(pos1.y, pos2.y),
    z: fn(pos1.z, pos2.z)
  )

func `==`* (pos1, pos2: Position): bool =
  ## Checks each element of `pos1` against each element of `pos2`.
  runnableExamples:
    doAssert Position.init(1, 2, 3) == Position.init(5, 4, 3) - Position.init(4, 2, 0)
  result = pos1.coord == pos2.coord

func `=~`* (pos1, pos2: Position): bool =
  ## Almost checks each element of `pos1` against each element of `pos2`.
  runnableExamples:
    doAssert Position.init(0.1, 0.2, 0.3) =~ Position.init(1.5, 1.3, 1.1) - Position.init(1.4, 1.1, 0.8)
  result = almostEqual(pos1.x, pos2.x) and
           almostEqual(pos1.y, pos2.y) and
           almostEqual(pos1.z, pos2.z)

func `+`* (pos: Position, value: float32): Position =
  ## Adds `value` to each element of `pos`.
  runnableExamples:
    doAssert Position.init(1, 2, 3) + 5.0 == Position.init(6, 7, 8)
  pos.map(v => v + value)

func `+`* (pos1, pos2: Position): Position =
  ## Adds each element of `pos2` to each element of `pos1`.
  runnableExamples:
    doAssert Position.init(1, 2, 3) + Position.init(4, 5, 6) == Position.init(5, 7, 9)
  map(pos1, pos2, (v1, v2) => v1 + v2)

func `-`* (pos: Position): Position =
  ## Multiplies each element of `pos` by -1.
  runnableExamples:
    doAssert -Position.init(1, 2, 3) == Position.init(-1, -2, -3)
  pos.map(v => -v)

func `-`* (pos: Position, value: float32): Position =
  ## Subtracts `value` to each element of `pos`.
  runnableExamples:
    doAssert Position.init(5, 6, 7) - 4.0 == Position.init(1, 2, 3)
  pos.map(v => v - value)

func `-`* (pos1, pos2: Position): Position =
  ## Subtracts each element of `pos2` from each element of `pos1`.
  runnableExamples:
    doAssert Position.init(10, 20, 30) - Position.init(1, 2, 3) == Position.init(9, 18, 27)
  map(pos1, pos2, (v1, v2) => v1 - v2)

func `*`* (pos: Position, value: float32): Position =
  ## Multiplies each element of `pos` by `value`.
  runnableExamples:
    doAssert Position.init(1, 2, 3) * 2.0 == Position.init(2, 4, 6)
  pos.map(v => v * value)

func `*`* (pos1, pos2: Position): Position =
  ## Multiplies each element of `pos1` by each element of `pos2`.
  runnableExamples:
    doAssert Position.init(5, 6, 7) * Position.init(4, 3, 2) == Position.init(20, 18, 14)
  map(pos1, pos2, (v1, v2) => v1 * v2)

func `/`* (pos: Position, value: float32): Position =
  ## Divides each element of `pos` by `value`
  runnableExamples:
    doAssert Position.init(14, 12, 10) / 2.0 == Position.init(7, 6, 5)
  pos.map(v => v / value)

func `/`* (pos1, pos2: Position): Position =
  ## Divides each element of `pos1` by each element of `pos2`
  runnableExamples:
    doAssert Position.init(21, 18, 15) / Position.init(7, 6, 5) == Position.init(3, 3, 3)
  map(pos1, pos2, (v1, v2) => v1 / v2)
