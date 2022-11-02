## src/nagu/vbo.nim defines the Triangle type and procedures.

from nimgl/opengl import nil
from program import Program, mvpMatrix, identityMatrix, index
from position import Position, map, coord
from old_vbo import vboRef, VBO, make, init, `:=`, id
from color import Color, rgb
from std/sugar import `->`, `=>`
from math import sin, cos, degToRad

type
  vboRefForTriangle = vboRef[9, float32]
  triangleArray = array[9, float32]

  TriangleObj = object
    p1, p2, p3: Position
    c1, c2, c3: Color
    position_vbo: vboRefForTriangle
    color_vbo: vboRefForTriangle
    mvp_matrix: mvpMatrix
  
  Triangle* = ref TriangleObj
    ## Represents triangles.

proc xAxisRotationMatrix (rotation: float32): mvpMatrix = [
  1.0f, 0,             0,              0,
  0,    cos(rotation), -sin(rotation), 0,
  0,    sin(rotation), cos(rotation),  0,
  0,    0,             0,              1
]

proc yAxisRotationMatrix (rotation: float32): mvpMatrix = [
  cos(rotation),  0, sin(rotation), 0,
  0,              1, 0,             0,
  -sin(rotation), 0, cos(rotation), 0,
  0,              0, 0,             1
]

proc zAxisRotationMatrix (rotation: float32): mvpMatrix = [
  cos(rotation), -sin(rotation), 0, 0,
  sin(rotation), cos(rotation),  0, 0,
  0,             0,              1, 0,
  0,             0,              0, 1
]

proc init* (_: typedesc[Triangle],
            p1: Position, c1: Color,
            p2: Position, c2: Color,
            p3: Position, c3: Color,
            x_axis_rotation: float32 = 0.0,
            y_axis_rotation: float32 = 0.0,
            z_axis_rotation: float32 = 0.0): Triangle =
  ## Initializes triangle by `p1`, `c1`, `p2`, `c2`, `p3`, `c3`, `x_axis_rotation`, `y_axis_rotation` and `z_axis_rotation`.
  let
    x_axis_rotation_matrix = xAxisRotationMatrix(x_axis_rotation.degToRad)
    y_axis_rotation_matrix = yAxisRotationMatrix(y_axis_rotation.degToRad)
    z_axis_rotation_matrix = zAxisRotationMatrix(z_axis_rotation.degToRad)
  result = Triangle(
    p1: p1, p2: p2, p3: p3,
    c1: c1, c2: c2, c3: c3,
    mvp_matrix: identityMatrix() # * x_axios_rotation_matrix
  )

proc init* (_: typedesc[Triangle], p1, p2, p3: Position, color: Color): Triangle =
  ## Initializes triangle by `p1`, `p2`, `p3` and `color`.
  result = Triangle(
    p1: p1, p2: p2, p3: p3,
    c1: color, c2: color, c3: color,
    mvp_matrix: identityMatrix()
  )

proc positionArray* (t: Triangle): triangleArray =
  let
    (p1x, p1y, p1z) = t.p1.coord
    (p2x, p2y, p2z) = t.p2.coord
    (p3x, p3y, p3z) = t.p3.coord
  result = [
    p1x, p1y, p1z,
    p2x, p2y, p2z,
    p3x, p3y, p3z
  ]

proc colorArray (t: Triangle): triangleArray =
  let
    (c1x, c1y, c1z) = t.c1.rgb
    (c2x, c2y, c2z) = t.c2.rgb
    (c3x, c3y, c3z) = t.c3.rgb
  result = [
    c1x, c1y, c1z,
    c2x, c2y, c2z,
    c3x, c3y, c3z
  ]

proc handle (t: Triangle): Triangle =
  result = t
  result.position_vbo = VBO.make(result.positionArray)
  result.color_vbo = VBO.make(result.colorArray)

proc make* (_: typedesc[Triangle], p1, p2, p3: Position, color: Color): Triangle =
  ## Initializes and handles triangle by `p1`, `p2`, `p3` and `color`.
  result = Triangle.init(p1, p2, p3, color).handle()

proc make* (_: typedesc[Triangle],
            p1: Position, c1: Color,
            p2: Position, c2: Color,
            p3: Position, c3: Color): Triangle =
  ## Initializes and handles triangle by `p1`, `c1`, `p2`, `c2`, `p3` and `c3`.
  result = Triangle.init(p1, c1, p2, c2, p3, c3).handle()

func pMap* (t: Triangle, fn: Position -> Position): Triangle =
  ## Applies `fn` to each positions of `t`.
  result = t
  result.p1 = fn(t.p1)
  result.p2 = fn(t.p2)
  result.p3 = fn(t.p3)

func cMap* (t: Triangle, fn: Color -> Color): Triangle =
  ## Applies `fn` to each colors of `t`.
  result = t
  result.c1 = fn(t.c1)
  result.c2 = fn(t.c2)
  result.c3 = fn(t.c3)

proc `+=`* (t: var Triangle, value: float32) =
  ## Adds `value` to each positions of `t`.
  t = t.pMap(p => (p.map(v => v + value)))
  t.position_vbo := t.positionArray

proc `-=`* (t: var Triangle, value: float32) =
  ## Subtracts `value` to each positions of `t`.
  t = t.pMap(p => (p.map(v => v - value)))
  t.position_vbo := t.positionArray

proc `*=`* (t: var Triangle, value: float32) =
  ## Multiplies `value` to each positions of `t`.
  t = t.pMap(p => (p.map(v => v * value)))
  t.position_vbo := t.positionArray

proc `/=`* (t: var Triangle, value: float32) =
  ## Divides `value` to each positions of `t`.
  t = t.pMap(p => (p.map(v => v / value)))
  t.position_vbo := t.positionArray

proc correspondPartially (program: Program, vbo: vboRefForTriangle, name: string, size: int) =
  let index = opengl.GLuint(program.index(name))
  opengl.glEnableVertexAttribArray(index)
  opengl.glBindBuffer(opengl.GL_ARRAY_BUFFER, vbo.id)
  opengl.glVertexAttribPointer(index, opengl.GLint(size), opengl.EGL_FLOAT, false, 0, nil)

proc correspond* (program: Program, t: Triangle, position_name, color_name: string, size: int) =
  ## Ties `t` to `program`.
  program.correspondPartially(t.position_vbo, position_name, size)
  program.correspondPartially(t.color_vbo, color_name, size)
