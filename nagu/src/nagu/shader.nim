## src/nagu/shader.nim defines the ShaderObject type and procedures related to its for abstracting OpenGL shader.

from nimgl/opengl import nil
from opengl as naguOpengl import OpenGLDefect

type
  ShaderObjectObj = object
    id: uint
  
  ShaderObject* = ref ShaderObjectObj
    ## The ShaderObject type representations OpenGL shader object.
  
  ShaderObjectKind* = enum
    ## The ShaderObjectKind type representations the kind of OpenGL shader.
    soVertex, soFragment, soGeometry, soTessEvaluation, soTessControl
  
  ShaderDefect* = object of OpenGLDefect
    ## Raised by something with OpenGL shaders.

  ShaderCreationDefect* = object of ShaderDefect
    ## Raised by creating OpenGL shaders.
  
  ShaderFailedCompilationDefect* = object of ShaderDefect
    ## Raised by failed compilation OpenGL shaders.

func convertGLExpression* (kind: ShaderObjectKind): opengl.GLenum =
  case kind:
  of soVertex: opengl.GL_VERTEX_SHADER
  of soFragment: opengl.GL_FRAGMENT_SHADER
  of soGeometry: opengl.GL_GEOMETRY_SHADER
  of soTessEvaluation: opengl.GL_TESS_EVALUATION_SHADER
  of soTessControl: opengl.GL_TESS_CONTROL_SHADER

proc init* (_: typedesc[ShaderObject], kind: ShaderObjectKind): ShaderObject {.raises: [ShaderCreationDefect, Exception].} =
  ## Initializes ShaderObject by `kind`.
  let shader = opengl.glCreateShader(kind.convertGLExpression)
  if shader == opengl.GLuint(0):
    # TODO: OpenGLからログを取って原因を出力する（よくバグるので, なぜ？） or 例外を切り替える
    raise newException(ShaderCreationDefect, "Failed to create the shader for some reason.")
  result = ShaderObject(id: shader)

func id* (shader: ShaderObject): uint =
  ## Gets ShaderObjectObj id.
  result = shader.id

proc log* (shader: ShaderObject): string =
  ## Gets logs about OpenGL shaders.
  var log_length: opengl.GLint
  opengl.glGetShaderiv(opengl.GLuint(shader.id), opengl.GL_INFO_LOG_LENGTH, log_length.addr)
  if log_length.int > 0:
    var
      log: cstring
      written_length: opengl.GLsizei
    opengl.glGetShaderInfoLog(opengl.GLuint(shader.id), log_length, written_length.addr, log)
    result = $log

proc load* (shader: ShaderObject, path: string): ShaderObject =
  ## Loads the shader from `path`.
  result = shader
  var shader_code: cstring = block:
    var shader_file = open(path)
    defer:
      shader_file.close()
    shader_file.readAll().cstring
  opengl.glShaderSource(opengl.GLuint(result.id), opengl.GLsizei(1), shader_code.addr, nil)

proc successCompile (shader: ShaderObject): bool =
  var res: opengl.GLint
  opengl.glGetShaderiv(opengl.GLuint(shader.id), opengl.GL_COMPILE_STATUS, res.addr)
  result = res == opengl.GLint(opengl.GL_TRUE)

proc compile* (shader: ShaderObject): ShaderObject {.raises: [ShaderFailedCompilationDefect, Exception].} =
  ## Compiles the shader in `shader`.
  result = shader
  opengl.glCompileShader(opengl.GLuint(result.id))
  if not result.successCompile:
    raise newException(ShaderFailedCompilationDefect, "Failed to compile the shader: ") # & result.log)

proc make* (_: typedesc[ShaderObject], kind: ShaderObjectKind, path: string): ShaderObject =
  ## Makes a compiled ShaderObject from `path`.
  result = ShaderObject
            .init(kind)
            .load(path)
            .compile()
