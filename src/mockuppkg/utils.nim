import times, macros
import glm, muml

const mockupInitializeMvpMatrix* = [
  1f, 0.0f, 0.0f, 0.0f,
  0.0f, 1f, 0.0f, 0.0f,
  0.0f, 0.0f, -1.0f, 0.0f,
  -0.5f, -0.5f, 0.0f, 1.0f
]

func naguCoordinate* [I: static int] (
  positions: array[I, Vec3[int]],
  header: mumlHeader
): array[I, Vec3[float32]] =
  for index in 0 ..< I:
    result[index][0] = positions[index][0] / header.width
    result[index][1] = positions[index][1] / header.height
    result[index][2] = positions[index][2].float32

template bench* (name: string, body: untyped): untyped =
  block:
    let now = now()
    body
    echo "name: ", now() - nows

proc buffer_offset* (num: int): ptr char =
  cast[ptr char](cast[int](cast[ptr char](nil)) + num)

template `~`*(path: string): string =
  when nimvm:
    getProjectPath() & "/../" & path
  else:
    "/" & path

macro `...`*(args: varargs[typed]): untyped =
  result = newStmtList()
  result.add newNimNode(nnkBracket)
  for node in args[0]:
    let sym = node[0]
    let impl = sym.getImpl
    let idx = node[1][1]
    for i in 0 ..< impl[2][0].len - 1:
      result[0].add quote do:
        `sym`[`idx`].arr[`i`]

template printOpenGLVersion* =
  echo "OpenGL Version: " & $glVersionMajor & "." & $glVersionMinor
