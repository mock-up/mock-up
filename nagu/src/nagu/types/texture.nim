from nimgl/opengl import nil
import ../vao, ../vbo, ../program, ../utils, ../mvp_matrix

type
  naguTextureQuad* = VBO[12, float32]
  naguBindedTextureQuad* = BindedVBO[12, float32]
  naguTextureUV* = VBO[8, float32]
  naguBindedTextureUV* = BindedVBO[8, float32]
  naguTextureElem* = VBO[6, uint8]
  naguBindedTextureElem* = BindedVBO[6, uint8]

  naguTextureObj [binded: static bool] = object
    id: opengl.GLuint
    vao*: VAO
    quad*: naguTextureQuad
    uv*: naguTextureUV
    elem*: naguTextureElem
    format: naguTextureFormat
    model_matrix*: array[4, ModelMatrixVector[16]]
    wrapS, wrapT: naguTextureWrapParameter
    magFilter: naguTextureMagFilterParameter
    minFilter: naguTextureMinFilterParameter
    program*: Program
    initializedPixels*: bool
  
  naguTexture* = ref naguTextureObj[false]
  naguBindedTexture* = ref naguTextureObj[true]
  naguAllTextures = naguTexture | naguBindedTexture

  naguTextureWrapParameter* {.pure.} = enum
    tInitialValue = 0
    tRepeat = opengl.GL_REPEAT
    tClampToEdge = opengl.GL_CLAMP_TO_EDGE
    tMirroredRepeat = opengl.GL_MIRRORED_REPEAT
  
  naguTextureMagFilterParameter* {.pure.} = enum
    tInitialValue = 0
    tNearest = opengl.GL_NEAREST
    tLinear = opengl.GL_LINEAR
  
  naguTextureMinFilterParameter* {.pure.} = enum
    tInitialValue = 0
    tNearest = opengl.GL_NEAREST
    tLinear = opengl.GL_LINEAR
    tNearestMipmapNearest = opengl.GL_NEAREST_MIPMAP_NEAREST
    tLinearMipmapNearest = opengl.GL_LINEAR_MIPMAP_NEAREST
    tNearestMipmapLinear = opengl.GL_NEAREST_MIPMAP_LINEAR
    tLinearMipmapLinear = opengl.GL_LINEAR_MIPMAP_LINEAR
  
  naguTextureFormat* {.pure.} = enum
    tfRGB = opengl.GL_RGB
    tfRGBA = opengl.GL_RGBA

func toBindedTexture* (texture: naguTexture): naguBindedTexture =
  result = naguBindedTexture(
    id: texture.id,
    vao: texture.vao,
    quad: texture.quad,
    uv: texture.uv,
    elem: texture.elem,
    format: texture.format,
    model_matrix: texture.model_matrix,
    wrapS: texture.wrapS, wrapT: texture.wrapT,
    magFilter: texture.magFilter,
    minFilter: texture.minFilter,
    program: texture.program
  )

func toTexture* (texture: naguBindedTexture): naguTexture =
  result = naguTexture(
    id: texture.id,
    vao: texture.vao,
    quad: texture.quad,
    uv: texture.uv,
    elem: texture.elem,
    format: texture.format,
    model_matrix: texture.model_matrix,
    wrapS: texture.wrapS, wrapT: texture.wrapT,
    magFilter: texture.magFilter,
    minFilter: texture.minFilter,
    program: texture.program
  )

func id* (texture: naguAllTextures): opengl.GLuint = texture.id

func format* (texture: naguAllTextures): naguTextureFormat = texture.format

func wrapS* (texture: naguAllTextures): naguTextureWrapParameter = texture.wrapS

func wrapT* (texture: naguAllTextures): naguTextureWrapParameter = texture.wrapT

func magFilter* (texture: naguAllTextures): naguTextureMagFilterParameter = texture.magFilter

func minFilter* (texture: naguAllTextures): naguTextureMinFilterParameter = texture.minFilter

proc `format=`* (texture: var naguBindedTexture, format: naguTextureFormat) =
  texture.format = format

proc assignParameterBoiler (texture: var naguBindedTexture, name: opengl.GLenum, param: opengl.GLint) =
  debugOpenGLStatement:
    echo &"glTexParameteri(opengl.GL_TEXTURE_2D, {name.repr}, {param.repr})"
  opengl.glTexParameteri(opengl.GL_TEXTURE_2D, name, param)

proc `wrapS=`* (texture: var naguBindedTexture, wrap_param: naguTextureWrapParameter) =
  texture.assignParameterBoiler(opengl.GL_TEXTURE_WRAP_S, opengl.GLint(wrap_param))

proc `wrapT=`* (texture: var naguBindedTexture, wrap_param: naguTextureWrapParameter) =
  texture.assignParameterBoiler(opengl.GL_TEXTURE_WRAP_T, opengl.GLint(wrap_param))

proc `magFilter=`* (texture: var naguBindedTexture, mag_filter_param: naguTextureMagFilterParameter) =
  texture.assignParameterBoiler(opengl.GL_TEXTURE_MAG_FILTER, opengl.GLint(mag_filter_param))

proc `minFilter=`* (texture: var naguBindedTexture, min_filter_param: naguTextureMinFilterParameter) =
  texture.assignParameterBoiler(opengl.GL_TEXTURE_MIN_FILTER, opengl.GLint(min_filter_param))

proc init* (_: typedesc[naguTexture],
            id: opengl.GLuint = 0,
            vao: VAO = nil,
            quad: naguTextureQuad = nil,
            uv: naguTextureUV = nil,
            elem: naguTextureElem = nil,
            model_matrix: array[4, ModelMatrixVector[16]],
            format: naguTextureFormat = tfRGBA,
            wrapS: naguTextureWrapParameter = naguTextureWrapParameter.tInitialValue,
            wrapT: naguTextureWrapParameter = naguTextureWrapParameter.tInitialValue,
            magFilter: naguTextureMagFilterParameter = naguTextureMagFilterParameter.tInitialValue,
            minFilter: naguTextureMinFilterParameter = naguTextureMinFilterParameter.tInitialValue,
            program: Program = nil): naguTexture =
  result = naguTexture(
    id: id,
    vao: vao, quad: quad, uv: uv, elem: elem,
    model_matrix: model_matrix,
    format: format,
    wrapS: wrapS, wrapT: wrapT,
    magFilter: magFilter, minFilter: minFilter, program: program
  )
  opengl.glGenTextures(1, result.id.addr)
  opengl.glActiveTexture(opengl.GL_TEXTURE0)
