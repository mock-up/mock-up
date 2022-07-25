import utils
from nimgl/opengl as gl import nil

type
  FilterKind* = enum
    ColorInversionFilter = "colorInversionFilter"
    IdFilter = "idFilter"

  MockupProgram = object

  MockupFilter* = object
    kind*: FilterKind

proc newFilter* (kind: FilterKind): MockupFilter =
  result.kind = kind

template checkResult (id: uint32, checkType: untyped, checkExeType: gl.GLenum) =
  var compileResult: int32
  gl.`glGet checkType iv`(id, checkExeType, compileResult.addr)
  if compileResult != gl.GL_TRUE.ord:
    var infoLogLength: int32
    gl.`glGet checkType iv`(id, gl.GL_INFO_LOG_LENGTH, infoLogLength.addr)
    if infoLogLength > 0:
      var message: cstring = newString(infoLogLength)
      gl.`glGet checkType InfoLog`(id, infoLogLength, nil, message[0].addr)
      if message[0] != '\0':
        echo "<" & astToStr(checkType InfoLog) & ">"
        echo message
        quit()

template compileShaderAux (shaderType: gl.GLenum, shaderCode: string): uint32 =
  var id = gl.glCreateShader(shaderType)
  var code: cstring = shaderCode
  gl.glShaderSource(id, 1'i32, code.addr, nil)
  gl.glCompileShader(id)
  # id.checkResult(Shader, gl.GL_COMPILE_STATUS)
  id

template compileShader (shaderType: gl.GLenum, path: static string): uint32 =
  #echo path
  #echo static staticRead(path)
  compileShaderAux(shaderType, static staticRead(path))

# template compileShader (shaderType: gl.GLenum, path: string): uint32 =
#   echo path
#   echo readFile(path)
#   compileShaderAux(shaderType, readFile(path))

template linkProgramTemplate* (shaders: varargs[uint32]): uint32 =
  var programID: uint32 = gl.glCreateProgram()
  for shader in shaders:
    gl.glAttachShader(programID, shader)
    var a: GLint = 0
    gl.glGetShaderiv(shader, gl.GL_COMPILE_STATUS, a.addr)
    # echo "linkProgramTemplate: ", a
    var log: array[100000, char]
    var size: GLint = 0
    gl.glGetShaderInfoLog(shader, 100000, size.addr, log.addr)
    for ch in log:
      stdout.write ch
    
  gl.glLinkProgram(programID)
  # programID.checkResult(Program, gl.GL_LINK_STATUS)
  for shader in shaders:
    gl.glDetachShader(programID, shader)
    gl.glDeleteShader(shader)
  programID

template linkProgram* (vertex_shader, fragment_shader: string): uint32 =
  linkProgramTemplate(
    compileShader(
      gl.GL_VERTEX_SHADER,
      vertex_shader
    ),
    compileShader(
      gl.GL_FRAGMENT_SHADER,
      fragment_shader
    )
  )

type
  ShaderKind = enum
    SKTexture = "textures"

template fragmentPath (shaderKind: ShaderKind, filterKind: FilterKind): string =
  ~"shaders/" & $shaderKind & "/fragment/" & $filterKind & ".glsl"

template vertexPath (shaderKind: ShaderKind, filterKind: FilterKind): string =
  ~"shaders/" & $shaderKind & "/vertex/" & $filterKind & ".glsl"

template linkTextureProgram* (filter: FilterKind): uint32 =
  var id: uint32 = linkProgram(
    ~("shaders/textures/vertex/" & $filter & ".glsl"),
    ~("shaders/textures/fragment/" & $filter & ".glsl")
  )
  id

template linkTriangleProgram* (filter: FilterKind): uint32 =
  var id: uint32 = linkProgram(
    ~("shaders/triangles/vertex/" & $filter & ".glsl"),
    ~("shaders/triangles/fragment/" & $filter & ".glsl")
  )
  id