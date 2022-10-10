import jester, uuids
import std/[json, db_sqlite, strformat]
import mockuppkg/[frames, opengl, utils, shaders, textures, streaming, triangle, encode_mp4, videos]
import nimgl/opengl as gl
import ffmpeg
import muml
import glm
import nagu

mumlDeserializer()

proc encode =
  let muml = readMuml("assets/live/livecoding.json")
  let header = muml.parseHeader

  let _ = initializeOpenGL(header.width.GLsizei, header.height.GLsizei)
  glClearColor(0.0f, 0.0f, 0.0f, 1.0f)

  let mumlElements = muml.deserialize()
  for element in mumlElements:
    if element of Video:
      echo Video(element)[]
    elif element of Triangle:
      echo Triangle(element)[]
    elif element of Rectangle:
      echo Rectangle(element)[]
    elif element of Text:
      echo Text(element)[]

  var video = mockupVideo.init(
    vec3(0, 0, 0),
    "assets/mockup.mp4",
    "shaders/textures/vertex/idFilter.glsl",
    "shaders/textures/fragment/idFilter.glsl"
  )

  var output_mp4 = openMP4(header.outputPath, int32(header.width), int32(header.height), int32(header.fps))

  video.seek(60000)

  for frame in video.decodeVideo(header):
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
    var frame = frame
    frame.draw()

    var triangle = naguTriangle.init(
      header,
      [vec3(0, 0, 0), vec3(500, 0, 0), vec3(500, 500, 0)],
      [vec4(1f, 0, 0, 0), vec4(0f, 1, 0, 1), vec4(0f, 0, 1, 1)],
      "shaders/shapes/id/id.vert",
      "shaders/shapes/id/id.frag"
    )
    triangle.use do (triangle: var naguBindedTriangle):
      triangle.draw(vdmTriangles)

    output_mp4.addFrame(readFrame(header.width.int32, header.height.int32).frame)

  output_mp4.close()

proc preview (muml: mumlNode) =
  let _ = initializeOpenGL(1920, 1080)
  let header = muml.parseHeader

  glClearColor(0.0f, 0.0f, 0.0f, 1.0f)

  let mumlElements = muml.deserialize()

  var video = mockupVideo.init(
    vec3(0, 0, 0),
    "assets/mockup.mp4",
    "shaders/textures/vertex/idFilter.glsl",
    "shaders/textures/fragment/idFilter.glsl"
  )

  var output_mp4 = openMP4(header.outputPath, int32(header.width), int32(header.height), int32(header.fps))

  for frame in video.decodeVideo(header):
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
    var frame = frame
    frame.draw()

    for element in mumlElements:
      if element of Video:
        discard
      elif element of Triangle:
        let
          pos = Triangle(element).position[0]
          x = pos.x.int
          y = pos.y.int
          z = pos.z.int
        echo x, " ", y, " ", z
        var triangle = naguTriangle.init(
          header,
          [vec3(x, y, z), vec3(x+500, y, z), vec3(x+500, y+500, z)],
          [vec4(1f, 0, 0, 0), vec4(0f, 1, 0, 1), vec4(0f, 0, 1, 1)],
          "shaders/shapes/id/id.vert",
          "shaders/shapes/id/id.frag"
        )
        triangle.use do (triangle: var naguBindedTriangle):
          triangle.draw(vdmTriangles)
      elif element of Rectangle:
        discard
      elif element of Text:
        discard

    output_mp4.addFrame(readFrame(header.width.int32, header.height.int32).frame)

  output_mp4.close()

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
          response = %*{ "message": &"プロジェクト{id}のmumlを更新しました" }
        db.exec(sql"update projects set muml=? where id=?", $params, $id)
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
        echo muml
        db.close()
        preview(muml.readMuml)
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
    encode()
    corsResp "エンコードの要求（動画パスを返却）"


when isMainModule:
  import cligen

  proc serveMockup (): int =
    let settings = newSettings(port=Port(5001))
    var jester = initJester(mockup_router, settings=settings)
    jester.serve()

  dispatchMulti(
    [serveMockup, cmdName = "serve"],
    [encode]
  )
