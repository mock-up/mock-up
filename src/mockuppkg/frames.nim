from ffmpeg import nil
import nagu, muml, glm
import utils

type
  FFmpegError* = object of ValueError
  
  mockupFrame* = object
    frame*: ptr ffmpeg.AVFrame
    naguTexture*: naguTexture

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

proc width* (frame: mockupFrame): int32 =
  result = frame.frame[].width

proc height* (frame: mockupFrame): int32 =
  result = frame.frame[].height

proc draw* (frame: var mockupFrame) =
  frame.naguTexture.use do (texture: var naguBindedTexture):
    texture.draw()

proc init* (T: type mockupFrame,
            header: mumlHeader,
            positions: array[4, Vec3[int]],
            vertex_shader_path: string,
            fragment_shader_path: string): mockupFrame =
  echo positions.naguCoordinate(header)
  result.naguTexture = naguTexture.make(
    positions.naguCoordinate(header),
    vertex_shader_path,
    fragment_shader_path,
    mockupInitializeMvpMatrix
  )

proc initFrame* (width, height: int32): ptr ffmpeg.AVFrame =
  result = ffmpeg.av_frame_alloc()
  result.format = ffmpeg.AV_PIX_FMT_RGBA.cint
  result.height = height
  result.width = width
  if ffmpeg.av_frame_get_buffer(result, 32) < 0:
    raise newException(Defect, "バッファの割り当てに失敗しました")

from nimgl/opengl import glReadPixels, GLsizei, GL_RGBA, GL_UNSIGNED_BYTE

proc readFrame* (width, height: int32): mockupFrame =
  result.frame = initFrame(width, height)
  glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, result.frame[].data[0])
