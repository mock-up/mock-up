## src/nagu/vbo.nim defines the VBO type and procedures related to its for abstracting OpenGL VBO.

from nimgl/opengl import nil
from program import Program

type
  vboObj [I: static[int]; T] = object
    id: opengl.GLuint
    data: array[I, T]
  
  vboRef* [I: static[int]; T] = ref vboObj[I, T]
  
  VBO* = object

proc init* [I, T] (_: typedesc[vboRef[I, T]]): vboRef[I, T] =
  ## Initializes vbo.
  result = vboRef[I, T]()
  opengl.glGenBuffers(1, result.id.addr)

func id* [I, T] (vbo: vboRef[I, T]): opengl.GLuint =
  result = vbo.id

func data* [I, T] (vbo: vboRef[I, T]): array[I, T] =
  result = vbo.data

proc bindArrayBuffer[I, T] (vbo: vboRef[I, T]): vboRef[I, T] =
  result = vbo
  opengl.glBindBuffer(opengl.GL_ARRAY_BUFFER, vbo.id)

proc assignArray[I, T] (vbo: var vboRef[I, T], data: array[I, T]) =
  vbo.data = data
  discard vbo.bindArrayBuffer()
  opengl.glBufferData(opengl.GL_ARRAY_BUFFER, vbo.data.len * sizeof(vbo.data[0]), vbo.data[0].addr, opengl.GL_STATIC_DRAW)

proc `:=`* [I, T] (vbo: var vboRef[I, T], data: array[I, T]) =
  ## Assigns `data` to `vbo`.
  vbo.assignArray(data)

proc make* [I: static[int]; T] (_: typedesc[VBO], data: array[I, T]): vboRef[I, T] =
  ## Makes vbo and assigns `data` to it.
  result = vboRef[I, T].init()
  result.data = data
  result := result.data

proc correspond* [I] (program: Program, vbo: vboRef[I, float32], name: string, size: int) =
  ## Ties `vbo` to `program`.
  let index = opengl.GLuint(program.nameToIndex[name])
  opengl.glEnableVertexAttribArray(index)
  opengl.glBindBuffer(opengl.GL_ARRAY_BUFFER, vbo.id)
  opengl.glVertexAttribPointer(index, opengl.GLint(size), opengl.EGL_FLOAT, false, 0, nil)
