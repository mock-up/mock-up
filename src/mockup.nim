# new => mock upプロジェクトの作成
# expand => mock up expandの作成
# serve => APIサーバーを建てる
# publish => expandの公開

when isMainModule:
  import cligen
  import mockup/[videos, images, opengl, utils, shaders, textures, streaming, triangle, encode_mp4]
  import std/times
  import std/strformat
  import json
  import muml
  import nimgl/opengl as gl
  import ffmpeg

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

    let now = getTime()
    let nowStr: string = format(now, "yyyy-MM-dd-HH-mm-ss")
    
    var output_mp4 = openMP4(&"movies/{nowStr}.mp4")

    for image in video:
      glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
      image.draw()
      for triangle in triangles:
        triangle.draw()
      # video.encode(image.readImage)
      output_mp4.addFrame(image.readImage.frame)
    
    for _ in 0 ..< 50:
      var frame = av_frame_alloc()
      frame.format = AV_PIX_FMT_RGBA.cint
      frame.height = video.height
      frame.width = video.width
      if av_frame_get_buffer(frame, 32) < 0:
        raise newException(Defect, "バッファの割り当てに失敗しました")
      glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
      glReadPixels(0, 0, video.width, video.height, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, frame.data[0])
      output_mp4.addFrame(frame)
      echo "来てる？そもそも"

    output_mp4.close()
    # video.finish()

  dispatchMulti(
    [mainEncode, cmdName = "encode"],
    [preview],
    [update],
    [test1]
  )
