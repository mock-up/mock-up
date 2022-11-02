# nagu - **N**im **A**bstract Open**G**L **U**tility

![](https://github.com/mock-up/nagu/workflows/build/badge.svg)
![](https://github.com/mock-up/nagu/workflows/docs/badge.svg)

nagu is Nimble Package for handling OpenGL statelessly. It provides utility procedures and object types for creating Program, VAO, VBO and compiling and linking shader files. Also you can reduce enough tasks you must consider because manages the state in OpenGL automatically behind the scenes.  
It is the library that [mock up](https://www.github.com/mock-up/mock-up) depends on, so as long as this continues to be developed, nagu will also be developed. On the other hand, we won't implement spontaneously functions this don't need. We welcome casual issues and pull requests.

## Installation
nagu supports Nim 1.6.2 and above and can be installed using Nimble.

```zsh
$ nimble install nagu
```
## Sample
```nim
proc main =
  let w = initializeOpenGL(500, 500)
  if w == nil:
    quit(-1)
  discard w.setKeyCallback(keyProc)
  w.makeContextCurrent()

  let
    vertex_shader = shaderObject.make(soVertex, "assets/basic.vert")
    fragment_shader = shaderObject.make(soFragment, "assets/basic.frag")
    program = programObject.make(vertex_shader, fragment_shader, @["VertexPosition", "VertexColor"], @["mvpMatrix"])
    vao_handle = VAO.make()
  
  var t1 = Triangle.make(
    Position.init(-1.0, -1.3, 0.0),
    "#0000ff".toColor,
    Position.init(-0.2, -1.3, 0.0),
    "#00ff00".toColor,
    Position.init(-0.2, -0.2, 0.0),
    "#ff0000".toColor
  )

  program.correspond(t1, "VertexPosition", "VertexColor", size=3)
  
  let mvp = [
    1/sqrt(2f), -1/sqrt(2f), 0, 0,
    1/sqrt(2f), 1/sqrt(2f), 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
  ]
  program.applyMatrix("mvpMatrix", mvp)

  w.mainLoop:
    clear("#ffffff".toColor)
    t1 += 0.001
    vao_handle.draw()
```