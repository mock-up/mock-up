when isMainModule:
  import cligen, os

  proc init (): int =
    createDir("frontend")
    createDir("backend")
    discard execShellCmd("cd frontend && git init")
    discard execShellCmd("cd frontend && git pull https://github.com/mock-up/mock-up-frontend-template.git")
    discard execShellCmd("cd frontend && npm install")
    discard execShellCmd("cd backend && git init")
    discard execShellCmd("cd backend && git pull https://github.com/mock-up/mock-up-backend-template.git")

  proc dev (): int =
    discard execShellCmd("cd frontend && npm run start")

  dispatchMulti(
    [init, cmdName = "new"],
    [dev]
  )