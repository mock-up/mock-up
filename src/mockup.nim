when isMainModule:
  import cligen, os, json
  import jester
  import mockuppkg/[video, timeline, fonts]
  import muml
  from fp import either

  proc init2 (): int =
    createDir("frontend")
    createDir("backend")
    discard execShellCmd("cd frontend && git init")
    discard execShellCmd("cd frontend && git pull https://github.com/mock-up/mock-up-frontend-template.git")
    discard execShellCmd("cd frontend && npm install")
    discard execShellCmd("cd backend && git init")
    discard execShellCmd("cd backend && git pull https://github.com/mock-up/mock-up-backend-template.git")

  proc dev (): int =
    var video = Video("assets/sample2.mp4")
    let muml = muml("assets/muml.json")
    echo video.output("assets/new_encoder.mp4", muml)

  proc server (): int =
    routes:
      post "/muml":
        var timeline = mTimeLine()
        let muml = request.body.parseJson.muml
        # for muml_obj in muml.content.element:
        #   timeline.add muml_obj
        # timeline.header = muml.header.getHeader
        # echo timeline.encode("assets/new_encoder.mp4")
        var video = Video("assets/src.mp4")
        echo video.output("assets/out/mitou1.mp4", muml)
        resp %*{"message": "Created"}

  dispatchMulti(
    [init2, cmdName = "new"],
    [dev],
    [server]
  )