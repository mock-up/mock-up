from nimgl/opengl as gl import nil

type
  MockupTexture* = object
    ## 画像であれ図形であれ、レイヤ層としてテクスチャに変換してから描画する
    id: gl.GLuint

proc newTexture* (width, height: gl.GLsizei): MockupTexture =
  gl.glGenTextures(1, result.id.addr)
  gl.glBindTexture(gl.GL_TEXTURE_2D, result.id)
  gl.glTexImage2D(
    gl.GL_TEXTURE_2D, 0, gl.GLint(gl.GL_RGBA),
    width, height, 0, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, nil
  )
  gl.glTexParameteri(
    gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S,
    gl.GLint(gl.GL_CLAMP_TO_EDGE)
  )
  gl.glTexParameteri(
    gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T,
    gl.GLint(gl.GL_CLAMP_TO_EDGE)
  )
  gl.glTexParameteri(
    gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER,
    gl.GLint(gl.GL_LINEAR)
  )
  gl.glTexParameteri(
    gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER,
    gl.GLint(gl.GL_LINEAR)
  )

proc setFrameBuffer* (texture: MockupTexture) =
  gl.glFramebufferTexture2D(
    gl.GL_FRAMEBUFFER, gl.GL_COLOR_ATTACHMENT0,
    gl.GL_TEXTURE_2D, texture.id, 0
  )
