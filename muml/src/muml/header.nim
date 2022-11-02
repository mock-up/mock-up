import std/[json, importutils]
import types, utils

privateAccess(mumlHeader)

func projectName* (header: mumlHeader): string = header.projectName
func width* (header: mumlHeader): int = header.width
func height* (header: mumlHeader): int = header.height
func frameCount* (header: mumlHeader): int = header.frameCount
func outputPath* (header: mumlHeader): string = header.outputPath
func fps* (header: mumlHeader): float = header.fps

proc parseHeader* (muml: mumlNode): mumlHeader =
  result = mumlHeader()
  for key, val in muml.header.pairs:
    case key:
    of "project_name":
      result.projectName = val.getStr.removeDoubleQuotation
    of "width": result.width = val.getInt
    of "height": result.height = val.getInt
    of "frame_count":
      result.frameCount = val.getInt
    of "output_path":
      result.outputPath = val.getStr.removeDoubleQuotation
    of "fps": result.fps = val.getFloat
