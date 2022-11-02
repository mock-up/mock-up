## src/nagu/vao.nim defines the VAO type and procedures related to its for abstracting OpenGL VAO.

from nimgl/opengl import nil
import utils
import std/strformat

type
  VAOObj [binded: static bool] = object
    id*: opengl.GLuint
  
  VAO* = ref VAOObj[false]
    ## The ProgramObject type representations OpenGL program object.
  
  BindedVAO* = ref VAOObj[true]

  VAODrawMode* = enum
    ## Represents VAO drawing mode.
    vdmPoints = opengl.GL_POINTS,
    vdmLines = opengl.GL_LINES,
    vdmLineLoop = opengl.GL_LINE_LOOP,
    vdmLineStrip = opengl.GL_LINE_STRIP,
    vdmTriangles = opengl.GL_TRIANGLES,
    vdmTriangleStrip = opengl.GL_TRIANGLE_STRIP,
    vdmTriangleFan = opengl.GL_TRIANGLE_FAN,
    vdmLinesAdjacency = opengl.GL_LINES_ADJACENCY,
    vdmLineStripAdjancency = opengl.GL_LINE_STRIP_ADJACENCY,
    vdmTrianglesAdjacency = opengl.GL_TRIANGLES_ADJACENCY,
    vdmTriangleStripAdjacency = opengl.GL_TRIANGLE_STRIP_ADJACENCY

proc init* (_: typedesc[VAO]): VAO =
  result = VAO()
  opengl.glGenVertexArrays(1, result.id.addr)
  debugOpenGLStatement:
    echo &"glGenVertexArrays(1, {result.id})"

proc `bind`* (vao: var VAO): BindedVAO =
  opengl.glBindVertexArray(vao.id)
  result = BindedVAO(id: vao.id)
  debugOpenGLStatement:
    echo &"glBindVertexArray({vao.id})"

proc unbind* =
  opengl.glBindVertexArray(0)
  debugOpenGLStatement:
    echo "glBindVertexArray(0)"

proc use* (vao: var VAO, procedure: proc (vao: var BindedVAO)) =
  var bindedVAO = vao.bind()
  bindedVAO.procedure()
  unbind()

proc make* (_: typedesc[VAO]): VAO =
  ## Initializes and binds VAO.
  result = VAO.init()

proc draw* (vao: BindedVAO, count: uint, mode: VAODrawMode) =
  ## Draws from `vao`.
  opengl.glDrawArrays(opengl.GLenum(mode), 0, opengl.GLsizei(count))
  debugOpenGLStatement:
    echo &"glDrawArrays({mode}, 0, {count})"

proc delete (vao: VAO) =
  opengl.glDeleteVertexArrays(1, vao.id.addr)
  debugOpenGLStatement:
    echo &"glDeleteVertexArrays(1, {vao.id})"
