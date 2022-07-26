import freetype, fp, math, unicode

type
  mockupFont* = object
    face: FT_Face
    slot: FT_GlyphSlot

proc init* : Either[string, FT_Library] =
  var library: FT_Library
  let err_code = FT_Init_FreeType(library)
  if err_code == 0:
    result = Right[string, FT_Library](library)
  else:
    result = Left[string, FT_Library]("FreeFontの初期化に失敗しました")

proc getFont* (library: FT_Library, path: string): mockupFont =
  discard FT_New_Face(library, path, 0, result.face)
  discard FT_Set_Pixel_Sizes(result.face, 0, 48)
  result.slot = result.face.glyph

# seq[int]の各要素に10ピクセルくらい開けて継ぎ足していけば実装できそう
proc getText* (font: mockupFont, text: string): seq[seq[int]] =
  var index = 0
  result = @[]
  while index < text.runeLen:
    discard FT_Load_Glyph(font.face, FT_Get_Char_Index(font.face, cast[culong](text.toRunes[index])), FT_LOAD_RENDER)
    let bitmap = font.face.glyph.bitmap
    var charas: seq[seq[int]] = @[]
    for row in 0..<bitmap.rows:
      var row_data: seq[int] = @[]
      for col in 0..<bitmap.pitch:
        var pixel_value = 0
        let c = bitmap.buffer[bitmap.pitch * row.int + col]
        for bit in countdown(7, 0):
          if not((c.int.shr(bit) and 1) == 0):
            pixel_value += 2 ^ bit
        row_data.add pixel_value
      if index == 0: charas.add row_data
      else: result[row].add row_data
    if index == 0:
      for i in 1..(50-bitmap.rows):
        var empty: seq[int] = @[]
        for j in 1..bitmap.pitch:
          empty.add 0
        charas.add empty
      result = charas
    else:
      for i in bitmap.rows..<50:
        for j in 1..bitmap.pitch:
          result[i].add 0
    for i in 0..<50:
      result[i].add @[0,0,0,0,0,0,0,0,0,0]
    index += 1