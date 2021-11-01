from nimgl/opengl as gl import nil
from glm import nil
import nimgl/glfw
#from nimgl/glfw import nil

proc initGlfw =
  doAssert glfw.glfwInit()
  glfw.glfwWindowHint(glfw.GLFWContextVersionMajor, 3)
  glfw.glfwWindowHint(glfw.GLFWContextVersionMinor, 3)
  glfw.glfwWindowHint(glfw.GLFWOpenglForwardCompat, glfw.GLFW_TRUE)
  glfw.glfwWindowHint(glfw.GLFWOpenglProfile, glfw.GLFW_OPENGL_CORE_PROFILE)
  glfw.glfwWindowHint(glfw.GLFWResizable, glfw.GLFW_FALSE)

proc keyProc(window: glfw.GLFWWindow, key: int32, scancode: int32, action: int32, mods: int32): void {.cdecl.} =
  if key == GLFWKey(Escape) and action == glfw.GLFWPress:
    glfw.setWindowShouldClose(window, true)

proc initializeOpenGL* (width, height: int32): glfw.GLFWWindow =
  initGlfw()
  result = glfw.glfwCreateWindow(width, height, "mock up", nil, nil)
  doAssert result != nil
  discard result.setKeyCallback(keyProc)
  result.makeContextCurrent()
  doAssert gl.glInit()
  gl.glEnable(gl.GL_TEXTURE_2D)

proc toRGB* (color: tuple[r, g, b: uint]): glm.Vec4f =
  result = glm.vec4f(
    color.r.float32 / 255,
    color.g.float32 / 255,
    color.b.float32 / 255,
    1.0
  )

template clearColorRGB* (rgb: glm.Vec3[float32], alpha: float32) =
  glClearColor(rgb.r, rgb.b, rgb.b, alpha)

template genVertexArrays*(n: gl.GLsizei): var uint32 =
  var vao: uint32
  glGenVertexArrays(n, vao.addr)
  vao

template genBuffers* (n: gl.GLsizei): var uint32 =
  var vbo: uint32
  glGenBuffers(n, vbo.addr)
  vbo