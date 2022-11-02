import std/unittest
from std/importutils import privateAccess
import nagu/position {.all.}

privateAccess(PositionObj)

suite "init":
  test "(1, 2, 3)":
    check Position.init(1, 2, 3)[] == PositionObj(x: 1.0, y: 2.0, z: 3.0)
  
  test "(1.1, 2.2, 3.3)":
    check Position.init(1.1, 2.2, 3.3)[] == PositionObj(x: 1.1, y: 2.2, z: 3.3)

suite "coord":
  test "(1, -1, 0)":
    check Position.init(1, -1, 0).coord == (1f, -1f, 0f)
  
  test "(1.2, -2.4, 3.6)":
    check Position.init(1.2, -2.4, 3.6).coord == (1.2f, -2.4f, 3.6f)

suite "+":
  test "(0, 0, 0) + 2":
    check Position.init(0, 0, 0) + 2 == Position.init(2, 2, 2)
  
  test "(2.5, -5.0, 7.5) + 2.5":
    check Position.init(2.5, -5.0, 7.5) + 2.5 =~ Position.init(5.0, -2.5, 10.0)

  test "(1, 2, 3) + (6, 5, 4)":
    check Position.init(1, 2, 3) + Position.init(6, 5, 4) == Position.init(7, 7, 7)

  test "(1.1, 1.2, 1.3) + (2.3, 2.2, 2.1)":
    check Position.init(1.1, 1.2, 1.3) + Position.init(2.3, 2.2, 2.1) =~ Position.init(3.4, 3.4, 3.4)

suite "-":
  test "-(1, -1, 0)":
    check -Position.init(1, -1, 0) == Position.init(-1, 1, 0)
  
  test "(1, 2, 3) - 1":
    check Position.init(1, 2, 3) - 1 == Position.init(0, 1, 2)
  
  test "(1.2, 3.4, 5.6) - 0.9":
    check Position.init(1.2, 3.4, 5.6) - 0.9 =~ Position.init(0.3, 2.5, 4.7)

  test "(4, 5, 6) - (1, 2, 3)":
    check Position.init(4, 5, 6) - Position.init(1, 2, 3) == Position.init(3, 3, 3)
  
  test "(7.8, 9.0, 12.3) - (4.5, 6.7, 7.8)":
    check Position.init(7.8, 9.0, 12.3) - Position.init(4.5, 6.7, 7.8) =~ Position.init(3.3, 2.3, 4.5)

suite "*":
  test "(1, 2, 3) * 10":
    check Position.init(1, 2, 3) * 10 == Position.init(10, 20, 30)
  
  test "(1.2, 3.4, 5.6) * 3":
    check Position.init(1.2, 3.4, 5.6) * 3 =~ Position.init(3.6, 10.2, 16.8)
  
  test "(4, 5, 6) * (7, 8, 9)":
    check Position.init(4, 5, 6) * Position.init(7, 8, 9) == Position.init(28, 40, 54)
  
  test "(1.1, 2.2, 3.3) * (4.4, 5.5, 6.6)":
    check Position.init(1.1, 2.2, 3.3) * Position.init(4.4, 5.5, 6.6) =~ Position.init(4.84, 12.1, 21.78)

suite "/":
  test "(4, 6, 8) / 2":
    check Position.init(4, 6, 8) / 2 == Position.init(2, 3, 4)
  
  test "(7.2, 2.4, 3.6) / 2.5":
    check Position.init(7.2, 2.4, 3.6) / 2.5 =~ Position.init(2.88, 0.96, 1.44)
  
  test "(15, 16, 17) / (5, 8, 17)":
    check Position.init(15, 16, 17) / Position.init(5, 8, 17) == Position.init(3, 2, 1)
  
  test "(4.8, 3.5, 5.1) / (16, 0.7, 3.4)":
    check Position.init(4.8, 3.5, 5.1) / Position.init(16, 7.0, 3.4) =~ Position.init(0.3, 0.5, 1.5)

suite "$":
  test "(1, 2, 3)":
    check $Position.init(1, 2, 3) == "(x: 1.0, y: 2.0, z: 3.0)"
  
  # TODO: Implement an output that rounds to the nearest error.
  # test "(1.1, -2.2, 3.3)":
  #   check $Position.init(1.1, -2.2, 3.3) == "(x: 1.1, y: -2.2, z: 3.3)"

suite "==":
  test "(1, 2, 3) + (4, 5, 6)":
    check Position.init(1, 2, 3) + Position.init(4, 5, 6) == Position.init(5, 7, 9)
  
  test "(1.1, 2.2, 3.3) + (4.4, 5.5, 6.6)":
    check not(Position.init(1.1, 2.2, 3.3) + Position.init(1.2, 2.3, 3.4) == Position.init(2.3, 4.5, 6.7))

suite "=~":
  test "(1, 2, 3) + (4, 5, 6)":
    check Position.init(1, 2, 3) + Position.init(4, 5, 6) =~ Position.init(5, 7, 9)
  
  test "(1.1, 2.2, 3.3) + (4.4, 5.5, 6.6)":
    check Position.init(1.1, 2.2, 3.3) + Position.init(1.2, 2.3, 3.4) =~ Position.init(2.3, 4.5, 6.7)

suite "map":
  setup:
    proc cube (n: float32): float32 {.used.} = n * n * n
    proc min (n, m: float32): float32 {.used.} =
      result = if n <= m: n
               else: m
  test "apply cube to (1, 2, 3)":
    check:
      Position.init(1, 2, 3).map(cube) == Position.init(1, 8, 27)
      Position.init(1.1, 2.2, 3.3).map(cube) =~ Position.init(1.331, 10.648, 35.937)
  
  test "apply min":
    check:
      map(Position.init(1, 2, 3), Position.init(3, 2, 1), min) == Position.init(1, 2, 1)
      map(Position.init(1.1, 2.2, 3.3), Position.init(3.2, 2.1, 1.0), min) =~ Position.init(1.1, 2.1, 1.0)
