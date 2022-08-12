from nimgl/opengl as gl import nil
from ffmpeg import nil

type
  FFmpegError* = object of ValueError
  
  MockupImage* = object
    frame*: ptr ffmpeg.AVFrame
    texture_id: gl.GLuint
    vao, vbo: uint32
    programID: uint32
    uniforms: Uniforms
    attributes: Attributes
    mvpMatrix: array[0..15, float32]
  
  Uniforms = tuple
    mvpMatrix, frameTex: gl.GLuint
  
  Attributes = tuple
    vertices, texCoords: gl.GLuint

proc prepareCopyFrame* (src: ptr ffmpeg.AVFrame): ptr ffmpeg.AVFrame =
  result = ffmpeg.av_frame_alloc()
  result[].format = src[].format
  result[].height = src[].height
  result[].width = src[].width
  result[].channels = src[].channels # ?
  result[].channel_layout = src[].channel_layout
  result[].nb_samples = src[].nb_samples
  result[].pts = src[].pts

proc copy* (src: ptr ffmpeg.AVFrame): ptr ffmpeg.AVFrame =
  result = prepareCopyFrame(src)
  if ffmpeg.av_frame_get_buffer(result, 32) < 0:
    raise newException(FFmpegError, "バッファの割り当てに失敗しました")
  if ffmpeg.av_frame_copy(result, src) < 0:
    raise newException(FFmpegError, "フレームデータのコピーに失敗しました")
  if ffmpeg.av_frame_copy_props(result, src) < 0:
    raise newException(FFmpegError, "フレームのメタデータのコピーに失敗しました")
  # 暗黙な変数resultの場合はポインタが生存するが、変数を明示的に定義して返すとポインタは死ぬ

proc width* (image: MockupImage): int32 =
  result = image.frame[].width

proc height* (image: MockupImage): int32 =
  result = image.frame[].height

proc newUniforms (programID: uint32): Uniforms =
  result.mvpMatrix = gl.GLuint(gl.glGetUniformLocation(programID, "mvpMatrix"))
  result.frameTex = gl.GLuint(gl.glGetUniformLocation(programID, "frameTex"))
  echo programID
  echo gl.glGetUniformLocation(programID, "mvpMatrix")

proc newAttributes (programID: uint32): Attributes =
  result.vertices = gl.GLuint(gl.glGetAttribLocation(programID, "vertex"))
  result.texCoords = gl.GLuint(gl.glGetAttribLocation(programID, "texCoord0"))

proc newMvpMatrix: array[0..15, float32] = [
  0.5f, 0.0f, 0.0f, 0.0f,
  0.0f, 0.5f, 0.0f, 0.0f,
  0.0f, 0.0f, -1.0f, 0.0f,
  -0.5f, -0.5f, 0.0f, 1.0f
]

proc quad: array[20, float32] = [
  -1.0'f32,  1.0'f32, 0.0'f32,  0.0'f32, 1.0'f32,
  -1.0'f32, -1.0'f32, 0.0'f32,  0.0'f32, 0.0'f32,
    1.0'f32, -1.0'f32, 0.0'f32,  1.0'f32, 0.0'f32,
    1.0'f32,  1.0'f32, 0.0'f32,  1.0'f32, 1.0'f32
]

proc textureXyzUv (width, height, project_width, project_height: int): array[20, float32] =
  let
    width: float32 = width / project_height
    height: float32 = height / project_height
  result = [
    -width, height, 0, 0, 1,
    -width, -height, 0, 0, 0,
    width, -height, 0, 1, 1,
    width, height, 0, 1, 1
  ]

proc elem: array[6, uint8] = [
  0'u8, 1'u8, 2'u8, 0'u8, 2'u8, 3'u8
]
  
proc newImage* (frame: ptr ffmpeg.AVFrame, programID: uint32): MockupImage =
  result.frame = frame
  result.programID = programID
  result.uniforms = newUniforms(programID)
  result.attributes = newAttributes(programID)
  var
    quad = quad()
    elemBuf: uint32
    elem = elem()
  gl.glUseProgram(programID)
  gl.glGenVertexArrays(1, result.vao.addr)
  gl.glBindVertexArray(result.vao)
  gl.glGenBuffers(1, result.vbo.addr)
  gl.glBindBuffer(gl.GL_ARRAY_BUFFER, result.vbo)
  gl.glBufferData(gl.GL_ARRAY_BUFFER, cint(sizeof(float) * quad.len), quad[0].addr, gl.GL_STATIC_DRAW)
  gl.glEnableVertexAttribArray(result.attributes.vertices)
  gl.glVertexAttribPointer(result.attributes.vertices, 3, gl.EGL_FLOAT, false, 20, nil)
  gl.glEnableVertexAttribArray(result.attributes.texCoords)
  gl.glVertexAttribPointer(result.attributes.texCoords, 2, gl.EGL_FLOAT, false, 20, cast[pointer](12))
  gl.glGenBuffers(1, elemBuf.addr)
  gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, elemBuf)
  gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, sizeof(elem), elem[0].addr, gl.GL_STATIC_DRAW)
  gl.glActiveTexture(gl.GL_TEXTURE0)
  gl.glGenTextures(1, result.texture_id.addr)
  gl.glBindTexture(gl.GL_TEXTURE_2D, result.texture_id)
  gl.glPixelStorei(gl.GL_UNPACK_ALIGNMENT, 1)
  gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GLint(gl.GL_REPEAT))
  gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GLint(gl.GL_REPEAT))
  gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GLint(gl.GL_LINEAR))
  gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GLint(gl.GL_LINEAR))
  gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GLint(gl.GL_RGBA), frame[].width, frame[].height, 0, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, nil)
  once:
    echo frame[].width, " ", frame[].height
  gl.glUniform1i(gl.GLint(result.uniforms.frameTex), 0)
  result.mvpMatrix = newMvpMatrix()
  gl.glUniformMatrix4fv(gl.GLint(result.uniforms.mvpMatrix), 1, false, result.mvpMatrix[0].addr)

proc updateImage* (image: var MockupImage, frame: ptr ffmpeg.AVFrame) =
  var copy_frame = frame.copy
  gl.glUseProgram(image.programID)
  gl.glBindVertexArray(image.vao)
  gl.glBindTexture(gl.GL_TEXTURE_2D, image.texture_id)
  gl.glTexSubImage2D(
    gl.GL_TEXTURE_2D, 0, 0, 0,
    image.width, image.height,
    gl.GL_RGBA, gl.GL_UNSIGNED_BYTE,
    copy_frame[].data[0]
  )
  image.frame = frame
  image.frame[].data[0] = copy_frame[].data[0]

proc draw* (image: MockupImage) =
  gl.glUseProgram(image.programID)
  gl.glBindVertexArray(image.vao)
  gl.glDrawElements(gl.GL_TRIANGLES, 6, gl.GL_UNSIGNED_BYTE, nil)
  gl.glBindVertexArray(0)
  gl.glUseProgram(0)

proc draw* (image: MockupImage, programID: uint32) =
  gl.glUseProgram(programID)
  gl.glBindVertexArray(image.vao)
  gl.glDrawElements(gl.GL_TRIANGLES, 6, gl.GL_UNSIGNED_BYTE, nil)
  gl.glBindVertexArray(0)
  gl.glUseProgram(0)

type
  RGBA = tuple
    red, green, blue, alpha: uint8
  RGBAPtr = tuple
    red, green, blue, alpha: ptr uint8

func `+` (left: ptr uint8, right: int): ptr uint8 =
  result = cast[ptr uint8](cast[int](left) + right)

func getRGBAPtr (frame: ptr ffmpeg.AVFrame, index: int): RGBAPtr {.inline.} =
  let framePtr = frame[].data[0]
  result.red = framePtr + index
  result.green = framePtr + index + 1
  result.blue = framePtr + index + 2
  result.alpha = framePtr + index + 3

proc getRGBA* (frame: ptr ffmpeg.AVFrame, x, y: int): RGBA {.inline.} =
  let rgba = frame.getRGBAPtr(y * frame[].linesize[0] + x * 4)
  result.red = rgba.red[]
  result.green = rgba.green[]
  result.blue = rgba.blue[]
  result.alpha = rgba.alpha[]

proc readImage* (image: MockupImage): MockupImage =
  var
    image = image
    frame = image.frame.copy
  gl.glReadPixels(0, 0, image.width, image.height, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, frame[].data[0])
  image.frame = frame
  result = image

proc initFrame* (width, height: int32): ptr ffmpeg.AVFrame =
  result = ffmpeg.av_frame_alloc()
  result.format = ffmpeg.AV_PIX_FMT_RGBA.cint
  result.height = height
  result.width = width
  if ffmpeg.av_frame_get_buffer(result, 32) < 0:
    raise newException(Defect, "バッファの割り当てに失敗しました")

proc readFrameFromOpenGL* (width, height: gl.GLsizei): MockupImage =
  result.frame = initFrame(width, height)
  gl.glReadPixels(0, 0, width, height, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, result.frame[].data[0])
