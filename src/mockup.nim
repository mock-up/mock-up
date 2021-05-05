when isMainModule:  
  import cligen, os

  proc init (): int =
    createDir("frontend")
    createDir("backend")
    let frontend_dir = currentSourcePath.parentDir().parentDir() & "/project/frontend"
    copyDir(frontend_dir, "frontend")
    discard execShellCmd("yarn --cwd frontend install")
    let backend_dir = currentSourcePath.parentDir().parentDir() & "/project/backend"
    copyDir(backend_dir, "backend")

  proc dev (): int =
    discard execShellCmd("yarn --cwd frontend start")

  dispatchMulti(
    [init, cmdName = "new"],
    [dev]
  )