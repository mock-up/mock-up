## src/nagu/program.nim defines the ProgramObject type and procedures related to its for abstracting OpenGL program.

from nimgl/opengl import nil
from shader import ShaderObject, id, ShaderObjectKind, convertGLExpression
from opengl as naguOpengl import OpenGLDefect
from std/tables import Table, initTable, len, `[]`, `[]=`
from std/strformat import `&`
import utils, vbo

type
  ProgramVariableKind* = enum
    pvkAttrib,
    pvkUniform,
    pvkSubroutineUniform

  ProgramObj [binded: static bool] = object
    id: opengl.GLuint
    linked: bool
    nameToIndex*: Table[string, tuple[index: int, kind: ProgramVariableKind]]
  
  Program* = ref ProgramObj[false]
    ## The ProgramObject type representations OpenGL program object.
  
  BindedProgram* = ref ProgramObj[true]

  ProgramDefect* = object of OpenGLDefect
    ## Raised by something with OpenGL programs.

  ProgramCreationDefect* = object of ProgramDefect
    ## Raised by creating OpenGL programs.

  ProgramLinkingDefect* = object of ProgramDefect
    ## Raised by linking OpenGL programs.

  ProgramNotExistsActiveUniformDefect* = object of ProgramDefect
    ## Raised by the condition that program don't have active uniform variables.
  
  ProgramNotExistsActiveSubroutineUniformDefect* = object of ProgramDefect

  mvpMatrix* = array[16, float32]
    ## Represents model view projection matrixes.

func identityMatrix*: mvpMatrix = [
  1.0'f, 0.0, 0.0, 0.0,
  0.0,   1.0, 0.0, 0.0,
  0.0,   0.0, 1.0, 0.0,
  0.0,   0.0, 0.0, 1.0
]
  ## Matrix which value does not change when applied.

proc init* (_: typedesc[Program]): Program =
  ## Initializes ProgramObject.
  let program = opengl.glCreateProgram()
  if program == opengl.GLuint(0):
    raise newException(ProgramCreationDefect, "Failed to create the program for some reason.")
  result = Program(
    id: program,
    linked: false,
    nameToIndex: initTable[string, (int, ProgramVariableKind)]()
  )

func id* (program: Program | BindedProgram): opengl.GLuint =
  ## Gets id of `program`.
  result = program.id

func linked* (program: Program | BindedProgram): bool =
  ## Gets `program` linked or not.
  result = program.linked

func index* (program: Program | BindedProgram, name: string): int =
  ## Queries `program` for `name` and corresponding index.
  result = program.nameToIndex[name].index

# FIXME: Programを消す
proc attach* (program: Program | var BindedProgram, shader: ShaderObject) =
  ## Attach `shader` to `program`.
  debugOpenGLStatement:
    echo &"glAttachShader({program.id}, {shader.id})"
  opengl.glAttachShader(program.id, opengl.GLuint(shader.id))

proc successLink (program: Program | BindedProgram): bool =
  var status: opengl.GLint
  opengl.glGetProgramiv(program.id, opengl.GL_LINK_STATUS, status.addr)
  debugOpenGLStatement:
    echo &"glGetProgramiv({program.id}, GL_LINK_STATUS, {status})"
  result = status == opengl.GLint(opengl.GL_TRUE)

# FIXME: PRogramを消す
proc log* (program: var Program | var BindedProgram): string =
  ## Gets logs about OpenGL programs.
  var log_length: opengl.GLint
  opengl.glGetProgramiv(program.id, opengl.GL_INFO_LOG_LENGTH, log_length.addr)
  if log_length.int > 0:
    var
      log: array[1000, cchar]
      written_length: opengl.GLsizei
    opengl.glGetProgramInfoLog(program.id, log_length, written_length.addr, log[0].addr)
    for logchar in log:
      if not (logchar == '\x00'):
        result.add logchar

func toBindedProgram (program: Program): BindedProgram =
  result = BindedProgram(
    id: program.id,
    linked: program.linked,
    nameToIndex: program.nameToIndex
  )

func toProgram (program: BindedProgram): Program =
  result = Program(
    id: program.id,
    linked: program.linked,
    nameToIndex: program.nameToIndex
  )

proc `bind`* (program: var Program): BindedProgram =
  ## Use `program` if it is linked.
  if program.linked:
    debugOpenGLStatement:
      echo &"glUseProgram({program.id})"
    opengl.glUseProgram(program.id)
    result = program.toBindedProgram

proc unbind* (program: var BindedProgram): Program =
  opengl.glUseProgram(0)
  debugOpenGLStatement:
    echo "glUseProgram(0)"
  result = program.toProgram

proc use* (program: var Program, procedure: proc (program: var BindedProgram)) =
  ## Use `program` if it is linked.
  var bindedProgram = program.bind()
  procedure(bindedProgram)
  program = bindedProgram.unbind()

# FIXME: Programを消す
proc link* (program: var Program | var BindedProgram) =
  ## Links `program`.
  debugOpenGLStatement:
    echo &"glLinkProgram({program.id})"
  opengl.glLinkProgram(program.id)
  if program.successLink:
    program.linked = true
  else:
    raise newException(ProgramLinkingDefect, "Failed to link shader program: " & program.log)

# FIXME: Programを消す
proc registerAttrib* (program: var Program | var BindedProgram, name: string) =
  ## Register an attrib variable named `name` in `program`
  let index = program.nameToIndex.len
  program.nameToIndex[name] = (index, pvkAttrib)
  debugOpenGLStatement:
    echo &"glBindAttribLocation({program.id}, {index}, {name})"
  opengl.glBindAttribLocation(program.id, opengl.GLuint(index), name)

# FIXME: Programを消す
proc registerUniform* (program: var Program | var BindedProgram, name: string) =
  ## Register a uniform variable named `name` in `program`
  let index = opengl.glGetUniformLocation(program.id, name).int
  if index == -1:
    raise newException(ProgramNotExistsActiveUniformDefect, &"Active Uniform variable {name} does not exist in GLSL.")
  program.nameToIndex[name] = (index, pvkUniform)

# FIXME: Programを消す
proc registerSubroutineUniform* (program: var Program | var BindedProgram, shaderType: ShaderObjectKind, name: string) =
  let index = opengl.glGetSubroutineUniformLocation(program.id, shaderType.convertGLExpression, name).int
  if index == -1:
    raise newException(ProgramNotExistsActiveSubroutineUniformDefect, &"Active Subroutine-Uniform variable {name} does not exist in GLSL.")
  program.nameToIndex[name] = (index, pvkSubroutineUniform)

proc make* (_: typedesc[Program], vertex_shader: ShaderObject, fragment_shader: ShaderObject): Program =
  ## Makes a program linking `vertex_shader` and `fragment_shader`.
  result = Program
            .init()
            .attach(vertex_shader)
            .attach(fragment_shader)
  result.link()

proc make* (_: typedesc[Program], vertex_shader: ShaderObject, fragment_shader: ShaderObject, attributes: seq[string] = @[], uniforms: seq[string] = @[], subroutine_uniforms: seq[(ShaderObjectKind, string)] = @[]): Program =
  ## Makes a program linking `vertex_shader` and `fragment_shader`; registering `attributes` and `uniforms`.
  result = Program
            .init()
  result.attach(vertex_shader)
  result.attach(fragment_shader)
  for attribute in attributes:
    result.registerAttrib(attribute)
  result.link()
  result.use do (program: var BindedProgram):
    for uniform in uniforms:
      program.registerUniform(uniform)
    for (shader_kind, subroutine_uniform) in subroutine_uniforms:
      program.registerSubroutineUniform(shader_kind, subroutine_uniform)

# FIXME: Programを消す
proc `[]`* (program: Program | BindedProgram, name: string): int =
  result = program.nameToIndex[name].index

# FIXME: Programを消す
proc `[]=`* (program: Program | BindedProgram, name: string, v1: int) =
  let index = program[name]
  opengl.glUniform1i(opengl.GLint(index), opengl.GLint(v1))

  debugOpenGLStatement:
    echo &"glUniform1i({index}, {v1})"

# FIXME: Programを消す
proc `[]=`* (program: Program | BindedProgram, name: string, matrix4v: array[16, float32]) =
  let index = program[name]
  var matrix4v = matrix4v
  opengl.glUniformMatrix4fv(opengl.GLint(index), 1, opengl.GLboolean(false), matrix4v[0].addr)
  
  debugOpenGLStatement:
    echo &"glUniformMatrix4fv(index, 1, false, {matrix4v})"

# FIXME: Programを消す
proc `[]=`* [I: static int, T] (program: Program | BindedProgram, name: string, data: tuple[vbo: BindedVBO[I ,T], size: int]) =
  let index = opengl.GLuint(program[name])
  opengl.glEnableVertexAttribArray(index)
  opengl.glVertexAttribPointer(index, opengl.GLint(data.size), opengl.EGL_FLOAT, false, opengl.GLSizei(0), cast[pointer](0))
