import nimgl/glfw
from nimgl/opengl import glInit, glEnable, GL_TEXTURE_2D
from opengl as naguOpengl import OpenGLDefect
from color import Color, rgb
from std/exitprocs import addExitProc

type
  NaguContextObj* = object
    glfw_initialized: bool
    gl_initialized: bool
    window: glfw.GLFWWindow
    clearColor*: Color

  NaguContext* = ref NaguContextObj
    ## Represents GLFW context

  GLFWDefect* = object of Defect
    ## Base defect type for exceptions for GLFW
  
  GLFWInitializeDefect* = object of GLFWDefect
    ## Raised by failed initializing GLFW
  
  WindowCreationDefect* = object of GLFWDefect
    ## Raised by failed creation GLFW Window
  
  OpenGLInitializeDefect* = object of OpenGLDefect
    ## Raised by failed initializing OpenGL
 
proc init (_: typedesc[NaguContext]): NaguContext =
  if not glfw.glfwInit():
    raise newException(GLFWInitializeDefect, "Failed initializing GLFW")
  result = NaguContext(
    glfw_initialized: true,
    gl_initialized: false,
    window: nil
  )
  glfw.glfwWindowHint(glfw.GLFWContextVersionMajor, 3)
  glfw.glfwWindowHint(glfw.GLFWContextVersionMinor, 3)
  glfw.glfwWindowHint(glfw.GLFWOpenglForwardCompat, glfw.GLFW_TRUE)
  glfw.glfwWindowHint(glfw.GLFWOpenglProfile, glfw.GLFW_OPENGL_CORE_PROFILE)
  glfw.glfwWindowHint(glfw.GLFWResizable, glfw.GLFW_FALSE)

proc initWindow (width, height: int32, title: string, monitor: glfw.GLFWMonitor, share: glfw.GLFWWindow, icon: bool): glfw.GLFWWindow =
  result = glfw.glfwCreateWindow(width, height, title, monitor, share, icon)
  if result == nil:
    raise newException(WindowCreationDefect, "Failed creation Window")

proc initOpenGL: bool =
  result = glInit()
  if not result:
    raise newException(OpenGLInitializeDefect, "Failed initializing OpenGL Context")

proc attention (window: glfw.GLFWWindow) =
  glfw.makeContextCurrent(window)

proc keyProc(window: glfw.GLFWWindow, key: int32, scancode: int32, action: int32, mods: int32): void {.cdecl.} =
  if key == GLFWKey(Escape) and action == glfw.GLFWPress:
    glfw.setWindowShouldClose(window, true)

proc setup* (width: int32 = 500, height: int32 = 500, title: string = "window"): NaguContext =
  ## Initializes OpenGL context and gets GLFW Window.
  result = NaguContext.init()
  addExitProc(proc () {.closure.} = glfw.glfwTerminate())
  result.window = initWindow(width, height, title, nil, nil, false)
  result.window.attention()
  discard result.window.setKeyCallback(keyProc)
  result.gl_initialized = initOpenGL()
  glEnable(GL_TEXTURE_2D)

proc isWindowOpen (context: NaguContext): bool =
  result = not context.window.windowShouldClose

proc destroyWindow (context: NaguContext) =
  context.window.destroyWindow()

proc pollEventsAndSwapBuffers (context: NaguContext) =
  glfw.glfwPollEvents()
  context.window.swapBuffers()

template update* (context: NaguContext, body: untyped) =
  ## The main-loop in GLFW Window.
  while context.isWindowOpen:
    body
    context.pollEventsAndSwapBuffers()
  context.destroyWindow()

proc clear* (context: var NaguContext, color: Color, alpha: float32 = 0f) =
  ## Fills a window with (`color`, `alpha`)
  if not (context.clearColor == color):
    let (r, g, b) = color.rgb
    opengl.glClearColor(r, g, b, alpha)
  opengl.glClear(opengl.GL_COLOR_BUFFER_BIT)

export isWindowOpen, pollEventsAndSwapBuffers, destroyWindow
