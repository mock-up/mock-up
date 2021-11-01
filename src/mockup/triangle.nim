import glm
import nimgl/[opengl]
import math

from opengl as mugl import toRGB

type
  MockupTriangle* = object
    positions*: array[3, tuple[x, y: float]]
    translation_diff_of_center_of_gravity: tuple[x, y: float]
    position*: tuple[x, y: float32] # 重心
    base_position: tuple[x, y: float32]
    colors*: array[3, tuple[r, g, b: uint]]
    base_size: uint # 初期化時の重心と各頂点の距離
    size*: uint

  GLTriangle = object
    positions: array[3, Vec3f]
    colors: array[3, Vec4f]
    vao, vbo: uint32
    index_buffer: uint32
    programID: uint32

const
  MvpMatrix = 0
  IdentityMatrix: array[0..15, float32] = [
    1.0f, 0.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f, 0.0f,
    0.0f, 0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f, 1.0f
  ]

proc newTriangle* (
  vpositions: array[3, Vec3f],
  vcolors: array[3, Vec4f],
  programID: uint32,
  mvpMatrix: array[16, float32] = IdentityMatrix
): GLTriangle =
  var
    mvpMatrix = mvpMatrix
    vertices: seq[float32]
    indecise = [0'u8, 1'u8, 2'u8]
    uniforms: array[1, GLuint]
  for item_index in 0..2:
    for value_index in 0..2:
      vertices.add vpositions[item_index][value_index]
    for value_index in 0..3:
      vertices.add vcolors[item_index][value_index]
  result.programID = programID
  glUseProgram(programID)
  glGenVertexArrays(1, result.vao.addr)
  glBindVertexArray(result.vao)
  glGenBuffers(1, result.vbo.addr)
  glBindBuffer(GL_ARRAY_BUFFER, result.vbo)
  glBufferData(GL_ARRAY_BUFFER, cint(sizeof(cfloat) * vertices.len), vertices[0].addr, GL_STATIC_DRAW)
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 3, EGL_FLOAT, false, 7 * sizeof(cfloat), nil)
  glEnableVertexAttribArray(1)
  glVertexAttribPointer(1, 4, EGL_FLOAT, false, 7 * sizeof(cfloat), cast[pointer](3 * sizeof(cfloat)))
  glGenBuffers(1, result.index_buffer.addr)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, result.index_buffer)
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indecise), indecise[0].addr, GL_STATIC_DRAW)
  uniforms[MvpMatrix] = glGetUniformLocation(programID, "mvpMatrix").GLuint
  glUniformMatrix4fv(uniforms[MvpMatrix].GLint, 1, false, mvpMatrix[0].addr)
  glBindVertexArray(0)
  glUseProgram(0)

var frame_num = 0'u

proc draw* (triangle: GLTriangle) =
  glUseProgram(triangle.programID)
  glBindVertexArray(triangle.vao)
  glDrawElements(GL_TRIANGLES, 3, GL_UNSIGNED_BYTE, nil)
  glBindVertexArray(0)
  glUseProgram(0)

proc newTriangle* (
  position: tuple[x, y: int],
  color: tuple[r, g, b: uint],
  size: uint,
  programID: uint32,
  x_theta: float32 = 0.0,
  y_theta: float32 = 0.0,
  animation: proc (triangle: var MockupTriangle, frame_num: uint) = proc (triangle: var MockupTriangle, frame_num: uint) = discard
): GLTriangle =
  var
    mt_pos1 = (position.x.float, (position.y + size.int).float)
    mt_pos2 = (position.x.float - sqrt(3.0) / 2 * size.float, (position.y - size.int).float / 2.0)
    mt_pos3 = (position.x.float + sqrt(3.0) / 2 * size.float, (position.y - size.int).float / 2.0)
    positions = [mt_pos1, mt_pos2, mt_pos3]
    mt_colors = [color, color, color]
    triangle = MockupTriangle(
      positions: positions,
      colors: mt_colors,
      size: size,
      base_size: size,
      position: (position.x.float32, position.y.float32),
      base_position: (position.x.float32, position.y.float32)
    )
  triangle.animation(frame_num)

  let
    size_rate = triangle.size.float32 / triangle.base_size.float32
    pos_diff = (
      x: (triangle.position.x - triangle.base_position.x) / 1280,
      y: (triangle.position.y - triangle.base_position.y) / 720
    )

  var mvp = [
    0.5f, 0.0f, 0.0f, 0.0f,
    0.0f, 0.5f, 0.0f, 0.0f,
    0.0f, 0.0f, -1.0f, 0.0f,
    -0.5f, -0.5f, 0.0f, 1.0f
  ]

  let
    poses = triangle.positions
    vpositions = [
      vec3f(poses[0].x / 1280, poses[0].y / 720, 0.0),
      vec3f(poses[1].x / 1280, poses[1].y / 720, 0.0),
      vec3f(poses[2].x / 1280, poses[2].y / 720, 0.0)
    ]
    colors = triangle.colors
    vcolors = [colors[0].toRGB, colors[1].toRGB, colors[2].toRGB]
  
  frame_num += 1
  
  result = newTriangle(vpositions, vcolors, programID, mvp)