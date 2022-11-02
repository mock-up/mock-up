## src/nagu/vao.nim defines the VAO type and procedures related to its for abstracting OpenGL VAO.

from nimgl/opengl import nil

type
  vaoObj = object
    id: opengl.GLuint
  
  VAO* = ref vaoObj
    ## The ProgramObject type representations OpenGL program object.
  
  vaoDrawMode* = enum
    ## Represents VAO drawing mode.
    dmPoints, dmLines, dmLineStrip, dmLineLoop,
    dmTriangles, dmTriangleStrip, dmTriangleFan,
    dmLinesAdjacency, dmLineStripAdjancency,
    dmTrianglesAdjacency, dmTriangleStripAdjacency

proc init* (_: typedesc[VAO]): VAO =
  result = VAO()
  opengl.glGenVertexArrays(1, result.id.addr)

func convertDrawMode (mode: vaoDrawMode): opengl.GLenum =
  result = case mode:
           of dmPoints: opengl.GL_POINTS
           of dmLines: opengl.GL_LINES
           of dmLineStrip: opengl.GL_LINE_STRIP
           of dmLineLoop: opengl.GL_LINE_LOOP
           of dmTriangles: opengl.GL_TRIANGLES
           of dmTriangleStrip: opengl.GL_TRIANGLE_STRIP
           of dmTriangleFan: opengl.GL_TRIANGLE_FAN
           of dmLinesAdjacency: opengl.GL_LINES_ADJACENCY
           of dmLineStripAdjancency: opengl.GL_LINE_STRIP_ADJACENCY
           of dmTrianglesAdjacency: opengl.GL_TRIANGLES_ADJACENCY
           of dmTriangleStripAdjacency: opengl.GL_TRIANGLE_STRIP_ADJACENCY

proc `bind`* (vao: VAO) =
  opengl.glBindVertexArray(vao.id)

proc unbind* (vao: VAO) =
  opengl.glBindVertexArray(0)

proc make* (_: typedesc[VAO]): VAO =
  ## Initializes and binds VAO.
  result = VAO.init()
  result.bind()

proc draw* (vao: VAO, mode: vaoDrawMode) =
  ## Draws from `vao`.
  vao.bind()
  opengl.glDrawArrays(mode.convertDrawMode, 0, 4)

proc delete* (vao: VAO) =
  opengl.glDeleteVertexArrays(1, vao.id.addr)
