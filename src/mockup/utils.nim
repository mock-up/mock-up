import times, macros

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
