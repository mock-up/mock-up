import std/[json]
import muml/[utils, builder, deserializer, types, header]
import muml/builtin/[triangle, rectangle, video, text, commonTypes]
export utils, video, rectangle, text, triangle, builder, deserializer, types, commonTypes, header

proc readMuml* (json: JsonNode): mumlNode =
  if not json.hasKey("muml"):
    raise newException(Exception, "no muml")
  if not json["muml"].hasKey("header"):
    raise newException(Exception, "no header")
  if not json["muml"].hasKey("contents"):
    raise newException(Exception, "no contents")

  result.header = json["muml"]["header"]
  result.contents = json["muml"]["contents"]

proc readMuml* (path: string): mumlNode =
  result = readmuml(parseFile(path))
