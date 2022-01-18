from nimgl/opengl as gl import nil

type
  MockupRenderBuffer* = object
    color_render_buffer*: gl.GLuint
    depth_render_buffer*: gl.GLuint
    frame_buffer*: gl.GLuint

proc newGLRenderBuffer: gl.GLuint =
  gl.glGenRenderbuffers(1, result.addr)
  gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, result)

proc newGLFrameBuffer: gl.GLuint =
  gl.glGenFramebuffers(1, result.addr)
  gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, result)

proc newRenderBuffer*: MockupRenderBuffer =
  result.color_render_buffer = newGLRenderBuffer()
  result.depth_render_buffer = newGLRenderBuffer()
  result.frame_buffer = newGLFrameBuffer()

proc attach* (render_buffer: MockupRenderBuffer) =
  gl.glFramebufferRenderbuffer(
    gl.GL_FRAMEBUFFER,
    gl.GL_COLOR_ATTACHMENT0,
    gl.GL_RENDERBUFFER,
    render_buffer.color_render_buffer
  )
  gl.glFramebufferRenderbuffer(
    gl.GL_FRAMEBUFFER,
    gl.GL_DEPTH_ATTACHMENT,
    gl.GL_RENDERBUFFER,
    render_buffer.depth_render_buffer
  )