proc removeDoubleQuotation* (str: string): string =
  result = str[0..str.len-1]

# proc getFloatValueProperty* (muml: mumlNode, name: string): mumlFloatRange =
#   result = (start: muml["value"]["start"][name].getFloat, `end`: muml["value"]["end"][name].getFloat)

# proc getFrame* (muml: mumlNode): mumlIntRange =
#   result = (start: muml["frame"]["start"].getInt, `end`: muml["frame"]["end"].getInt)

# proc getNumberValue* (muml: mumlNode): seq[mumlValue] =
#   result = @[]
#   case muml.kind:
#   of JInt, JFloat:
#     var value = mumlValue()
#     value.frame = (-1, -1)
#     value.value = (muml.getFloat, NAN)
#     result.add value
#   of JArray:
#     for item in muml.items:
#       var value = mumlValue()
#       value.frame = item.getFrame
#       value.value = item.getFloatValueProperty("value")
#       result.add value
#   else: raise newException(Exception, "invalid value")

# proc getPosition* (muml: mumlNode): seq[muml2DPosition] =
#   result = @[]
#   case muml.kind:
#   of JObject:
#     var position = muml2DPosition()
#     position.frame = (-1, -1)
#     position.x = (muml["x"].getFloat, NAN)
#     position.y = (muml["y"].getFloat, NAN)
#     result.add position
#   of JArray:
#     for item in muml.items:
#       var position = muml2DPosition()
#       position.frame = item.getFrame
#       position.x = item.getFloatValueProperty("x")
#       position.y = item.getFloatValueProperty("y")
#       result.add position
#   else: raise newException(Exception, "invalid value")

# proc getScale* (muml: mumlNode): seq[mumlScale] =
#   result = @[]
#   case muml.kind:
#   of JObject:
#     var scale = mumlScale()
#     scale.frame = (-1, -1)
#     scale.width = (muml["width"].getFloat, NAN)
#     scale.height = (muml["height"].getFloat, NAN)
#     result.add scale
#   of JArray:
#     for item in muml:
#       var scale = mumlScale()
#       scale.width = item.getFloatValueProperty("width")
#       scale.height = item.getFloatValueProperty("height")
#       result.add scale
#   else: raise newException(Exception, "invalid value")

# proc getRGB* (muml: mumlNode): seq[mumlRGB] =
#   result = @[]
#   case muml.kind:
#   of JObject:
#     var color = mumlRGB()
#     color.frame = (-1, -1)
#     var
#       red = muml["red"].getFloat
#       green = muml["green"].getFloat
#       blue = muml["blue"].getFloat
#     color.color = newRGB(red.tBinaryRange, green.tBinaryRange, blue.tBinaryRange)
#     result.add color
#   of JArray:
#     for item in muml:
#       var color = mumlRGB()
#       color.frame = (-1, -1)
#       var
#         red = muml["red"].getFloat
#         green = muml["green"].getFloat
#         blue = muml["blue"].getFloat
#       color.color = newRGB(red.tBinaryRange, green.tBinaryRange, blue.tBinaryRange)
#       result.add color
#   else: raise newException(Exception, "invalid value")

# proc getFilters* (muml: mumlNode): seq[mumlFilter] =
#   result = @[]
#   case muml.kind:
#   of JArray:
#     for item in muml:
#       for key, value in item:
#         case key:
#         of "colorInversion":
#           result.add mumlFilter(
#             kind: colorInversion,
#             red: value["red"].getBool,
#             green: value["green"].getBool,
#             blue: value["blue"].getBool
#           )
#         of "grayScale":
#           result.add mumlFilter(
#             kind: grayScale,
#             value: value["value"].getFloat
#           )
#   else: raise newException(Exception, "invalid value")