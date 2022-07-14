# new => mock upプロジェクトの作成
# expand => mock up expandの作成
# serve => APIサーバーを建てる
# publish => expandの公開

when isMainModule:
  import cligen
  import ../mockup/[videos, images, opengl, utils, shaders, textures, streaming, triangle]
  import json
  import muml
  import nimgl/opengl as gl

  var videoContent: mumlNode

  proc test1: int =
    let _ = initializeOpenGL(1920, 1080)
    getEmptyVideo("assets/out/test1.mp4")
    
  proc update (muml: string): int =
    let muml = muml.parseJson.muml
    videoContent = muml.content

  proc preview: int =
    let _ = initializeOpenGL(1920, 1080)
    let muml = muml("assets/live/livecoding.json")
    let content = muml.content

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
    var video: MockupVideo
    var triangles: seq[GLTriangle]
    
    for mumlObj in content.element:
      let mockupVideoPath = "assets/mockup.mp4"
      case mumlObj.kind
      of mumlKindVideo:
        let filters = mumlObj.video.filters
        if filters.len == 0:
          video = newVideo(mockupVideoPath, linkTextureProgram(IdFilter))
        elif filters[0].kind == colorInversion:
          video = newVideo(mockupVideoPath, linkTextureProgram(ColorInversionFilter))
        else:
          raise newException(IOError, "no filter")
      of mumlKindTriangle:
        let triangleProgram = linkTriangleProgram(IdFilter)
        let position = mumlObj.triangle.position[0]
        let color = mumlObj.triangle.color[0]
        let size = mumlObj.triangle.scale[0]
        let triangle = newTriangle(
          (position.x.start.int, position.y.start.int),
          (color.color.red.uint, color.color.green.uint, color.color.blue.uint),
          size.width.start.uint,
          triangleProgram,
        )
        triangles.add triangle
      else: discard

    var mainTexture = newTexture(video.width, video.height)
    mainTexture.setFrameBuffer()

    var stream = initStreaming("rtmp://localhost/live_ffmpeg_1/stream", video)
    for image in video:
      glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
      image.draw()
      for triangle in triangles:
        triangle.draw()
      stream.sendFrame(image.readImage)
    
    stream.finish()

  proc mainEncode: int =
    let _ = initializeOpenGL(1920, 1080)
    let muml = muml("assets/live/livecoding.json")
    let content = muml.content

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
    var video: MockupVideo
    var triangles: seq[GLTriangle]
    
    for mumlObj in content.element:
      let mockupVideoPath = "assets/mockup.mp4"
      case mumlObj.kind
      of mumlKindVideo:
        let filters = mumlObj.video.filters
        if filters.len == 0:
          video = newVideo(mockupVideoPath, linkTextureProgram(IdFilter))
        elif filters[0].kind == colorInversion:
          video = newVideo(mockupVideoPath, linkTextureProgram(ColorInversionFilter))
        else:
          raise newException(IOError, "no filter")
      of mumlKindTriangle:
        let triangleProgram = linkTriangleProgram(IdFilter)
        let position = mumlObj.triangle.position[0]
        let color = mumlObj.triangle.color[0]
        let size = mumlObj.triangle.scale[0]
        let triangle = newTriangle(
          (position.x.start.int, position.y.start.int),
          (color.color.red.uint, color.color.green.uint, color.color.blue.uint),
          size.width.start.uint,
          triangleProgram,
        )
        triangles.add triangle
      else: discard

    var mainTexture = newTexture(video.width, video.height)
    mainTexture.setFrameBuffer()

    for image in video:
      glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
      image.draw()
      for triangle in triangles:
        triangle.draw()
      video.encode(image.readImage)
    
    video.finish()

  dispatchMulti(
    [mainEncode, cmdName = "encode"],
    [preview],
    [update],
    [test1]
  )
