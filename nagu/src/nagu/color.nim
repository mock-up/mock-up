## src/nagu/color.nim defines the Color type and procedures.

from Palette import rgb, tColor
from std/strformat import `&`

type
  ColorObj = object
    r, g, b: float32
  
  Color* = ref ColorObj
    ## Represents RGB Color.

func init* (_: typedesc[Color], r, g, b: range[0.0..1.0]): Color =
  ## Initializes Color.
  result = Color(r: r, g: g, b: b)

proc `$`* (color: Color): string =
  result = &"(red: {color.r}, green: {color.g}, blue: {color.b})"

func rgb* (color: Color): tuple[r, g, b: float32] =
  ## Gets rgb in `color`.
  result = (color.r, color.g, color.b)

proc toColor* (hex: string): Color =
  ## Converts `hex` into Color.
  let rgb = hex.rgb
  result = Color(
    r: rgb.red / 255.0,
    g: rgb.green / 255.0,
    b: rgb.blue / 255.0
  )

proc toColor* (color: tColor): Color =
  ## Converts `color` into Color.
  let rgb = color.hsv.rgb
  result = Color(
    r: rgb.red / 255.0,
    g: rgb.green / 255.0,
    b: rgb.blue / 255.0
  )

proc `+`* (hex: string): Color =
  result = ("#" & hex).toColor()
