## src/nagu/shape.nim defines the Shape type and procedures related to its.

from position import Position, coord, init
from color import Color, rgb, init
from vao import VAO, draw, VAODrawMode
from old_vbo import VBO, vboRef, data, `:=`
from program import mvpMatrix, ProgramObject
import nimgl/opengl

from std/sugar import `->`, `=>`

type
  ShapeObj[I: static int] = object
    vao: VAO
    positions_vbo: vboRef[I, float32]
    colors_vbo: vboRef[I, float32]
    mvp_matrix: mvpMatrix

  Shape* [I: static int] = ref ShapeObj[I]
    ## Represents shapes.

func toArray [I: static int] (positions: array[I, Position]): array[3*I, float32] =
  for index, position in positions:
    (result[index*3], result[index*3+1], result[index*3+2]) = position.coord

func toArray [I: static int] (colors: array[I, Color]): array[3*I, float32] =
  for index, color in colors:
    (result[index*3], result[index*3+1], result[index*3+2]) = color.rgb

func `@`* [I: static int] (positions: array[I, Position]): array[3*I, float32] =
  result = positions.toArray()

func `@`* [I: static int] (colors: array[I, Color]): array[3*I, float32] =
  result = colors.toArray()

func positions* [I: static int] (shape: Shape[I]): array[I div 3, Position] =
  let
    positions_len = I div 3
    data = shape.positions_vbo.data
  for index in 0 ..< positions_len:
    result[index] = Position.init(data[index*3], data[index*3+1], data[index*3+2])

func colors* [I: static int] (shape: Shape[I]): array[I div 3, Color] =
  let
    colors_len = I div 3
    data = shape.colors_vbo.data
  for index in 0 ..< colors_len:
    result[index] = Color.init(data[index*3], data[index*3+1], data[index*3+2])

proc init* [I: static int] (_: typedesc[Shape[I]], positionsArr: array[I, float32], colorsArr: array[I, float32]): Shape[I] =
  result = Shape[I](
    vao: VAO.make(),
    positions_vbo: VBO.make(positionsArr),
    colors_vbo: VBO.make(colorsArr)
  )
  ## vboRef[I*3, float32]は推論が効かずコンパイルが通らない
  # echo I
  # echo typeof result
  # echo typeof result.positions_vbo

proc draw* [I: static int] (shape: Shape[I], mode: VAODrawMode) =
  shape.vao.draw(mode)

proc pMap* [I: static int] (shape: var Shape[I], fn: Position -> Position) =
  var positions: array[I div 3, Position]
  for index, position in shape.positions:
    positions[index] = fn(position)
  shape[].positions_vbo := @positions

func cMap* [I: static int] (shape: Shape[I], fn: Color -> Color): Shape[I] =
  result = shape
  for index, color in shape.colors:
    result[index] = fn(color)
  result.colors_vbo := result.colors

proc correspondPartially [I: static int] (program: ProgramObject, vbo: vboRef[I, float32], name: string, size: int) =
  let index = opengl.GLuint(program.index(name))
  opengl.glEnableVertexAttribArray(index)
  opengl.glBindBuffer(opengl.GL_ARRAY_BUFFER, vbo.id)
  opengl.glVertexAttribPointer(index, opengl.GLint(size), opengl.EGL_FLOAT, false, 0, nil)

proc correspond* [I: static int] (program: ProgramObject, shape: Shape[I], position_name, color_name: string) =
  ## Ties `shape` to `program`.
  program.correspondPartially(shape.positions_vbo, position_name, 3)
  program.correspondPartially(shape.colors_vbo, color_name, 3)

# proc `+`* [I: static int] (shape: Shape[I], position: Position): Shape[I] =
#   result = shape.pMap(p => p + position)

proc `+=`* [I: static int] (shape: var Shape[I], position: Position) =
  shape.pMap(p => p + position)

# proc `-`* [I: static int] (shape: Shape[I], position: Position): Shape[I] =
#   result = shape.pMap(p => p - position)

proc `-=`* [I: static int] (shape: var Shape[I], position: Position) =
  shape.pMap(p => p - position)

# proc `*`* [I: static int] (shape: Shape[I], position: Position): Shape[I] =
#   result = shape.pMap(p => p * position)

proc `*=`* [I: static int] (shape: var Shape[I], position: Position) =
  shape.pMap(p => p * position)

# proc `/`* [I: static int] (shape: Shape[I], position: Position): Shape[I] =
#   result = shape.pMap(p => p / position)

proc `/=`* [I: static int] (shape: var Shape[I], position: Position) =
  shape.pMap(p => p * position)
