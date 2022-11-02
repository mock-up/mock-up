import std/json

type
  mumlNode* = object
    header: JsonNode
    contents: JsonNode

  mumlHeader* = object
    projectName: string
    width: int
    height: int
    frameCount: int
      ## プロジェクト全体のフレーム数
    outputPath: string
    fps: float

func header* (muml: mumlNode): JsonNode =
  result = muml.header

func contents* (muml: mumlNode): JsonNode =
  result = muml.contents

proc `header=`* (muml: var mumlNode, header: JsonNode) =
  muml.header = header

proc `contents=`* (muml: var mumlNode, contents: JsonNode) =
  muml.contents = contents
