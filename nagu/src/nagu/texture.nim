from nimgl/opengl import nil
import glm
import vao, vbo, program, shader, utils, position, mvp_matrix
import types/texture
import strformat

import tables

proc `bind` (texture: var naguTexture): naguBindedTexture =
  opengl.glBindTexture(opengl.GL_TEXTURE_2D, texture.id)
  result = texture.toBindedTexture

  debugOpenGLStatement:
    echo &"glBindTexture(GL_TEXTURE_2D, {texture.id})"

proc unbind (bindedTexture: var naguBindedTexture): naguTexture =
  opengl.glBindTexture(opengl.GL_TEXTURE_2D, 0)
  result = bindedTexture.toTexture

  debugOpenGLStatement:
    echo &"glBindTexture(GL_TEXTURE_2D, 0)"

proc use* (texture: var naguTexture, procedure: proc (texture: var naguBindedTexture)) =
  var bindedTexture = texture.bind()
  discard bindedTexture.program.bind()
  bindedTexture.procedure()
  texture = bindedTexture.unbind()

proc useVAO* (bindedTexture: var naguBindedTexture, procedure: proc (texture: var naguBindedTexture, vao: var BindedVAO)) =
  var bindedVAO = bindedTexture.vao.bind()
  procedure(bindedTexture, bindedVAO)
  vao.unbind()

proc useElem* (bindedTexture: var naguBindedTexture, procedure: proc (texture: var naguBindedTexture, vbo: var naguBindedTextureElem)) =
  var bindedVBO = bindedTexture.elem.bind()
  procedure(bindedTexture, bindedVBO)
  bindedTexture.elem = bindedVBO.unbind()

proc useQuad* (bindedTexture: var naguBindedTexture, procedure: proc (texture: var naguBindedTexture, vbo: var naguBindedTextureQuad)) =
  var bindedVBO = bindedTexture.quad.bind()
  procedure(bindedTexture, bindedVBO)
  bindedTexture.quad = bindedVBO.unbind()

proc useUV* (bindedTexture: var naguBindedTexture, procedure: proc (texture: var naguBindedTexture, vbo: var naguBindedTextureUV)) =
  var bindedVBO = bindedTexture.uv.bind()
  procedure(bindedTexture, bindedVBO)
  bindedTexture.uv = bindedVBO.unbind()

proc useModelMatrix* (bindedTexture: var naguBindedTexture, procedure: proc (texture: var naguBindedTexture, vbo: var array[4, BindedModelMatrixVector[16]])) =
  discard
  # var
  #   bindedVec1VBO = bindedTexture.model_matrix[0].bind()
  # procedure(bindedTexture, bindedVBO)
  # bindedTexture.model_matrix[index] = bindedVBO.unbind()
  # めっちゃ難しい。行列に対する操作をしつつbind管理もしなければいけない
  # 仮想的な行列を持って置いて、代入するタイミングで順番にuseModelMatrixVectorを回すのが良いのかも。

proc useModelMatrixVector* (bindedTexture: var naguBindedTexture, index: range[0..3], procedure: proc (texture: var naguBindedTexture, vbo: var BindedModelMatrixVector[16])) =
  var bindedVBO = bindedTexture.model_matrix[index].bind()
  procedure(bindedTexture, bindedVBO)
  bindedTexture.model_matrix[index] = bindedVBO.unbind()

proc textureImage2DOrSubImage2D (texture: var naguBindedTexture, format: naguTextureFormat, width, height: uint, pixels_pointer: ptr uint8) =
  if texture.initializedPixels:
    opengl.glTexSubImage2D(
      opengl.GL_TEXTURE_2D, 0, 0, 0,
      opengl.GLsizei(width), opengl.GLsizei(height),
      opengl.GLenum(format), opengl.GL_UNSIGNED_BYTE, pixels_pointer
    )
    debugOpenGLStatement:
      echo &"glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, {width}, {height}, GL_RGB, GL_UNSIGNED_BYTE, pixels)"
  else:
    opengl.glTexImage2D(
      opengl.GL_TEXTURE_2D, 0, opengl.GLint(opengl.GLenum(format)),
      opengl.GLsizei(width), opengl.GLsizei(height), 0,
      opengl.GLenum(format), opengl.GL_UNSIGNED_BYTE, pixels_pointer
    )
    texture.initializedPixels = true
    debugOpenGLStatement:
      echo &"glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, {width}, {height}, 0, GL_RGB, GL_UNSIGNED_BYTE, pixels)"

proc `pixels=`* [W, H: static uint] (texture: var naguBindedTexture, img: array[H, array[W, array[3, uint8]]]) =
  var data = img
  texture.textureImage2DOrSubImage2D(W, H, data[0].addr)

proc `pixels=`* (texture: var naguBindedTexture, img: tuple[data: seq[uint8], width: uint, height: uint]) =
  var data = img.data
  texture.textureImage2DOrSubImage2D(texture.format, img.width, img.height, data[0].addr)

proc `pixels=`* (texture: var naguBindedTexture, img: tuple[data: ptr uint8, width: uint, height: uint]) =
  texture.textureImage2DOrSubImage2D(texture.format, img.width, img.height, img.data)

proc draw* (texture: var naguBindedTexture) =
  texture.useVAO do (texture: var naguBindedTexture, vao: var BindedVAO):
    # texture.useElem do (texture: var naguBindedTexture, vbo: var BindedTextureElem):
    opengl.glDrawArrays(opengl.GLenum(vdmTriangleFan), 0, 4)

    debugOpenGLStatement:
      echo &"glDrawArrays(vdmTriangleFan, 0, 4)"

proc pixelStore (texture: var naguBindedTexture, pname: opengl.GLenum, param: opengl.GLint) =
  opengl.glPixelStorei(pname, param)

  debugOpenGLStatement:
    echo &"glPixelStorei({pname.repr}, {param.repr})"

func quad (positions: array[4, Vec3[float32]]): array[12, float32] =
  var index = 0
  for position in positions:
    result[index*3] = position[0]
    result[index*3+1] = position[1]
    result[index*3+2] = position[2]
    index += 1

func uv: array[8, float32] = [
  0.0'f32, 1.0,
  0.0,     0.0,
  1.0,     0.0,
  1.0,     1.0
]

func elem: array[6, uint8] = [
  0'u8, 1, 2, 0, 2, 3
]

# proc `[]=`* (texture: var naguBindedTexture, name: string, matrix4v: array[16, float32]) =
# そのうち一般化する、VBO名に依存したuse関数を作るのをやめる、customなvertex attrib変数に対して
# 適用できるUse関数を定義する
# VBOを専用のフィールドで持つのではなくテーブルに持っておくと良いと思う
proc setModelMatrix* (texture: var naguBindedTexture, matrix4v: array[16, float32]) =
  for index in 0 ..< 4:
    let matrix = [
      matrix4v[index*4], matrix4v[index*4+1], matrix4v[index*4+2], matrix4v[index*4+3],
      matrix4v[index*4], matrix4v[index*4+1], matrix4v[index*4+2], matrix4v[index*4+3],
      matrix4v[index*4], matrix4v[index*4+1], matrix4v[index*4+2], matrix4v[index*4+3],
      matrix4v[index*4], matrix4v[index*4+1], matrix4v[index*4+2], matrix4v[index*4+3],
    ]
    texture.useModelMatrixVector(index) do (texture: var naguBindedTexture, vbo: var BindedModelMatrixVector[16]):
      vbo.data = matrix
      texture.program[&"modelMatrixVec{index+1}"] = (vbo, 4)

proc toArray[T] (matrix4v: Mat4[T]): array[16, T] =
  for vec_index, vec in matrix4v.arr:
    for elem_index, elem in vec.arr:
      result[vec_index * 4 + elem_index] = elem

proc setModelMatrix* (texture: var naguBindedTexture, matrix4v: Mat4[float32]) =
  setModelMatrix(texture, matrix4v.toArray)

proc make* (_: typedesc[naguTexture],
            positions: array[4, Vec3[float32]],
            vertex_shader_path: string,
            fragment_shader_path: string,
            mvpMatrix = identityMatrix()
           ): naguTexture =

  result = naguTexture.init(
    vao = VAO.init(),
    quad = naguTextureQuad.init(),
    uv = naguTextureUV.init(),
    elem = naguTextureElem.init(),
    model_matrix = ModelMatrix[16].init()
  )

  let
    vertex_shader = ShaderObject.make(soVertex, vertex_shader_path)
    fragment_shader = ShaderObject.make(soFragment, fragment_shader_path)

  result.program = Program.make(
    vertex_shader,
    fragment_shader,
    @["vertex", "texCoord0", "modelMatrixVec1", "modelMatrixVec2", "modelMatrixVec3", "modelMatrixVec4"],
    @["frameTex", "mvpMatrix"],
    # @[(soVertex, "mvpMatrix")]
  )
  
  result.use do (texture: var naguBindedTexture):
    texture.useVAO do (texture: var naguBindedTexture, vao: var BindedVAO):
      texture.pixelStore(opengl.GL_UNPACK_ALIGNMENT, 1)

      texture.useQuad do (texture: var naguBindedTexture, vbo: var naguBindedTextureQuad):
        `data=`(vbo, quad(positions))
        texture.program["vertex"] = (vbo, 3)

      texture.useUV do (texture: var naguBindedTexture, vbo: var naguBindedTextureUV):
        `data=`(vbo, uv())
        texture.program["texCoord0"] = (vbo, 2)
      
      texture.useElem do (texture: var naguBindedTexture, vbo: var naguBindedTextureElem):
        var elem = elem()
        `target=`(vbo, vtArrayBuffer)
        `usage=`(vbo, vuStaticDraw)
        `data=`(vbo, elem)

      texture.program["frameTex"] = 0
      
      texture.setModelMatrix(identityMatrix())
      texture.program["mvpMatrix"] = mvpMatrix
      
      `wrapS=`(texture, tRepeat)
      `wrapT=`(texture, tRepeat)
      `magFilter=`(texture, naguTextureMagFilterParameter.tLinear)
      `minFilter=`(texture, naguTextureMinFilterParameter.tLinear)
