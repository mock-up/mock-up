# nagu - **N**im **A**bstract Open**G**L **U**tility
naguはステートレスにOpenGLを扱うためのNimble Packageです。
シェーダのコンパイルやリンク、ProgramやVAO、VBO作成のためのユーティリティプロシージャやオブジェクト型を提供します。また、naguはOpenGL開発における**状態**を裏で機械的に管理するため開発者が考えるべきタスクを十分に減らすことができます。  
naguは[mock up](https://www.github.com/mock-up/mock-up)の依存ライブラリとなっており、これが開発され続ける限りnaguも開発されますが、一方でmock upに必要ない機能は自発的に実装されません。気軽なIssue、Pull Requestを歓迎しています。

## インストール
Nim 1.6.2以上をサポートしており、Nimbleを使ってインストールできます。

```zsh
$ nimble install nagu
```

## サンプル
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