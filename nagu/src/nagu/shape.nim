import vao, vbo, mvp_matrix, shader, program
import glm
import std/strformat

type
  ShapeObj* [
    binded: static bool,
    vertex_num: static int,
    vertex_num_3x: static int,
    vertex_num_4x: static int
  ] = object
    vao: VAO
    positions: VBO[vertex_num_3x, float32] # 本来は 3*V
    colors: VBO[vertex_num_4x, float32] # 本来は 4*V
    model_matrix: array[4, VBO[vertex_num_4x, float32]] # 本来は 4*V
    program: Program

  Shape* [
    vertex_num: static int,
    vertex_num_3x: static int,
    vertex_num_4x: static int
  ] = ref ShapeObj[false, vertex_num, vertex_num_3x, vertex_num_4x]

  # Shape* [vertex_num, vertex_num_3x, vertex_num_4x: static int] = concept x
  #   vertex_num * 3 == vertex_num_3x
  #   vertex_num * 4 == vertex_num_4x
  #   x is ShapeBase
  
  BindedShape* [
    vertex_num: static int,
    vertex_num_3x: static int,
    vertex_num_4x: static int
  ] = ref ShapeObj[true, vertex_num, vertex_num_3x, vertex_num_4x]

proc `$`* [V, V3x, V4x: static int] (shape: Shape[V, V3x, V4x] | BindedShape[V, V3x, V4x]): string =
  result = &"Shape[{V}, {V3x}, {V4x}]" & "\n"
  result &= $shape.vao[] & "\n"
  result &= $shape.positions[] & "\n"
  result &= $shape.colors[] & "\n"
  result &= $shape.model_matrix[0][] & "\n"
  result &= $shape.model_matrix[1][] & "\n"
  result &= $shape.model_matrix[2][] & "\n"
  result &= $shape.model_matrix[3][] & "\n"
  result &= $shape.program[] & "\n"

func toBindedShape [V, V3x, V4x: static int] (shape: Shape[V, V3x, V4x]): BindedShape[V, V3x, V4x] =
  result = BindedShape[V, V3x, V4x](
    vao: shape.vao,
    positions: shape.positions,
    colors: shape.colors,
    model_matrix: shape.model_matrix,
    program: shape.program
  )

func toShape [V, V3x, V4x: static int] (shape: BindedShape[V, V3x, V4x]): Shape[V, V3x, V4x] =
  result = Shape[V, V3x, V4x](
    vao: shape.vao,
    positions: shape.positions,
    colors: shape.colors,
    model_matrix: shape.model_matrix,
    program: shape.program
  )

proc use* [V, V3x, V4x: static int] (shape: var Shape[V, V3x, V4x], procedure: proc (shape: var BindedShape[V, V3x, V4x])) =
  discard shape.program.bind()
  discard shape.vao.bind()
  var bindedShape = shape.toBindedShape
  procedure(bindedShape)
  shape = bindedShape.toShape
  # Programをunbindする？

proc useVAO* [V, V3x, V4x: static int] (shape: var BindedShape[V, V3x, V4x], procedure: proc (shape: var BindedShape[V, V3x, V4x], vao: var BindedVAO)) =
  var bindedVAO = shape.vao.bind()
  procedure(shape, bindedVAO)
  unbind() # TODO: 本当は変更後のBindedVAOを代入する方が良い（ここでは必要ない）
  shape = shape
  # shape.vao = bindedVAO.unbind()

proc usePositions* [V, V3x, V4x: static int] (shape: var BindedShape[V, V3x, V4x], procedure: proc (shape: var BindedShape[V, V3x, V4x], vbo: var BindedVBO[V3x, float32])) =
  var bindedVBO = shape.positions.bind()
  procedure(shape, bindedVBO)
  shape = shape
  shape.positions = bindedVBO.unbind()

proc usePositions* [V, V3x, V4x: static int] (shape: var BindedShape[V, V3x, V4x], procedure: proc (shape: var BindedShape[V, V3x, V4x], vao: var BindedVAO, vbo: var BindedVBO[V3x, float32])) =
  var
    bindedVAO = shape.vao.bind()
    bindedVBO = shape.positions.bind()
  procedure(shape, bindedVAO, bindedVBO)
  shape.positions = bindedVBO.unbind()

proc useColors* [V, V3x, V4x: static int] (shape: var BindedShape[V, V3x, V4x], procedure: proc (shape: var BindedShape[V, V3x, V4x], vbo: var BindedVBO[V4x, float32])) =
  var bindedVBO = shape.colors.bind()
  procedure(shape, bindedVBO)
  shape = shape
  shape.colors = bindedVBO.unbind()

func toArray [V, V3x, V4x: static int] (_: BindedShape[V, V3x, V4x], vector: array[V, Vec3[float32]]): array[V3x, float32] =
  for vec_index, vec in vector:
    for elem_index, elem in vec.arr:
      result[vec_index*3 + elem_index] = elem

func toArray [V, V3x, V4x: static int] (_: BindedShape[V, V3x, V4x], vector: array[V, Vec4[float32]]): array[V4x, float32] =
  for vec_index, vec in vector:
    for elem_index, elem in vec.arr:
      result[vec_index*4 + elem_index] = elem

proc useModelMatrixVector* [V, V3x, V4x: static int] (bindedShape: var BindedShape[V, V3x, V4x], index: range[0..3], procedure: proc (shape: var BindedShape[V, V3x, V4x], vbo: var BindedModelMatrixVector[V4x])) =
  var bindedVBO = bindedShape.model_matrix[index].bind()
  procedure(bindedShape, bindedVBO)
  bindedShape.model_matrix[index] = bindedVBO.unbind()

proc setModelMatrix* [V, V3x, V4x: static int] (shape: var BindedShape[V, V3x, V4x], matrix4v: array[16, float32]) =
  for index in 0 ..< 4:
    var matrix: array[V4x, float32]
    for matrix_gen_index in 0 ..< V:
      matrix[matrix_gen_index*4] = matrix4v[index*4]
      matrix[matrix_gen_index*4+1] = matrix4v[index*4+1]
      matrix[matrix_gen_index*4+2] = matrix4v[index*4+2]
      matrix[matrix_gen_index*4+3] = matrix4v[index*4+3]
    shape.useModelMatrixVector(index) do (shape: var BindedShape[V, V3x, V4x], vbo: var BindedModelMatrixVector[V4x]):
      `data=`(vbo, matrix)
      shape.program[&"modelMatrixVec{index+1}"] = (vbo, 4)

proc toArray[T] (matrix4v: Mat4[T]): array[16, T] =
  for vec_index, vec in matrix4v.arr:
    for elem_index, elem in vec.arr:
      result[vec_index * 4 + elem_index] = elem

proc make* [V, V3x, V4x: static int] (
  _: typedesc[Shape[V, V3x, V4x]],
  positions: array[V, Vec3[float32]],
  colors: array[V, Vec4[float32]],
  vertex_shader_path: string,
  fragment_shader_path: string,
  mvpMatrix = identityMatrix()
): Shape[V, V3x, V4x] =
  result = Shape[V, V3x, V4x](
    vao: VAO.init(),
    positions: VBO[V3x, float32].init(),
    colors: VBO[V4x, float32].init(),
    model_matrix: ModelMatrix[V4x].init()
  )
  ## FIXME: depend on VBO[16, float32]
  
  let
    vertex_shader = ShaderObject.make(soVertex, vertex_shader_path)
    fragment_shader = ShaderObject.make(soFragment, fragment_shader_path)

  result.program = Program.make(
    vertex_shader,
    fragment_shader,
    @["vertexPositions", "vertexColors", "modelMatrixVec1", "modelMatrixVec2", "modelMatrixVec3", "modelMatrixVec4"],
    @["mvpMatrix"],
  )

  discard result.program.bind()

  result.use do (shape: var BindedShape[V, V3x, V4x]):
    shape.usePositions do (shape: var BindedShape[V, V3x, V4x], vbo: var BindedVBO[V3x, float32]):
      `data=`(vbo, toArray(shape, positions))
      shape.program["vertexPositions"] = (vbo, 3)
    shape.useColors do (shape: var BindedShape[V, V3x, V4x], vbo: var BindedVBO[V4x, float32]):
      `data=`(vbo, toArray(shape, colors))
      shape.program["vertexColors"] = (vbo, 4)

    shape.setModelMatrix(identityMatrix())
    shape.program["mvpMatrix"] = mvpMatrix

proc draw* [V, V3x, V4x: static int] (shape: var BindedShape[V, V3x, V4x], mode: VAODrawMode) =
  shape.usePositions do (shape: var BindedShape[V, V3x, V4x], vao: var BindedVAO, vbo: var BindedVBO[V3x, float32]):
    vao.draw(V, mode)
