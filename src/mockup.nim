import jester, uuids
import std/[json, db_sqlite, strformat, times]
import mockup/[videos, images, opengl, utils, shaders, textures, streaming, triangle, encode_mp4]
import muml
import nimgl/opengl as gl
import ffmpeg

proc encode =
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
  
  var output_mp4 = openMP4(&"movies/{nowStr}.mp4", 1920, 1080, 60)

  for image in video:
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
    image.draw()
    for triangle in triangles:
      triangle.draw()
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

  output_mp4.close()

proc preview (muml: mumlNode) =
  let _ = initializeOpenGL(1920, 1080)
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

  var stream = initStreaming("rtmp://localhost:1935/app", video)
  for image in video:
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
    image.draw()
    for triangle in triangles:
      triangle.draw()
    stream.sendFrame(image.readImage)
  
  stream.finish()

proc existsProject (db: DbConn, id: string): bool =
  result = db.getValue(sql"select id FROM projects where id = ?", id) == id

template corsResp (message: untyped): untyped =
  mixin resp
  resp Http200, [("Access-Control-Allow-Origin", "*"), ("Access-Control-Allow-Headers", "Content-Type")], message

template corsResp (code, message: untyped): untyped =
  mixin resp
  resp code, [("Access-Control-Allow-Origin", "*"), ("Access-Control-Allow-Headers", "Content-Type")], message

template corsResp (code, header, message: untyped): untyped =
  mixin resp
  resp code, [("Access-Control-Allow-Origin", "*"), ("Access-Control-Allow-Headers", "Content-Type")] & header, message

router mockup_router:
  post "/projects/new":
    let
      project_id = $genUUID()
      response = %*{ "project_id": project_id }
      db = open("db/mockup.db", "", "", "")
    db.exec sql"create table if not exists projects (id string, muml text)"
    db.exec(sql"insert into projects (id, muml) values (?, ?)", project_id, "")
    db.close()
    corsResp $response
  
  options "/projects/@id/update":
    corsResp Http200, "ok"

  post "/projects/@id/update":
    let
      db = open("db/mockup.db", "", "", "")
      id = @"id"
    if db.existsProject(id):
      try:
        let
          params = request.body.parseJson
          muml = $params["muml"]
          response = %*{ "message": &"プロジェクト{id}のmumlを更新しました" }
        db.exec(sql"update projects set muml=? where id=?", $muml, $id)
        db.close()
        corsResp $response
      except Exception:
        let response = %*{ "message": getCurrentExceptionMsg() }
        corsResp Http500, $response
    else:
      db.close()
      let response = %*{ "message": "存在しないプロジェクトです" }
      corsResp Http400, $response
  
  get "/projects/@id/preview":
    let
      db = open("db/mockup.db", "", "", "")
      id = @"id"
    if db.existsProject(id):
      try:
        let
          response = %*{ "message": &"プロジェクト{id}のプレビューを要求しました" }
          muml = db.getValue(sql"select muml from projects where id = ?", id).parseJson
        db.close()
        preview(muml)
        corsResp $response
      except Exception:
        echo getCurrentException().repr()
        let response = %*{ "message": getCurrentExceptionMsg() }
        corsResp Http500, $response
    else:
      db.close()
      let
        response = %*{ "message": "存在しないプロジェクトです" }
      corsResp Http400, $response
  
  get "/projects/@id/encode":
    corsResp "エンコードの要求（動画パスを返却）"


when isMainModule:
  import cligen

  proc serveMockup (): int =
    let settings = newSettings(port=Port(5001))
    var jester = initJester(mockup_router, settings=settings)
    jester.serve()

  dispatchMulti(
    [serveMockup, cmdName = "serve"]
  )
