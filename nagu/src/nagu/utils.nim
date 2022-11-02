import os

proc getFileNameAndLine: tuple[path: string, line: int] =
  let
    stack_trace = getStackTraceEntries()
    last_stack_trace = stack_trace[stack_trace.high-2]
  result = ($last_stack_trace.filename, last_stack_trace.line)

template debugOpenGLStatement* (body: untyped): untyped =
  when defined(debuggingOpenGL):
    let (path, line) = getFileNameAndLine()
    stdout.write path & "(" & $line & ") "
    body