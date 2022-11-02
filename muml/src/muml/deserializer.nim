import std/macros, json, builder
import builtin/commonTypes
import uuids

const BuiltInElements* = [
  "Video", # "image", "audio",
  "Triangle",
  "Rectangle", "Text"
]

proc caseOfApplyParserAST (elements: seq[string]): NimNode =
  result = nnkCaseStmt.newTree(
    nnkDotExpr.newTree(
      nnkBracketExpr.newTree(
        newIdentNode("element"),
        newLit("type")
      ),
      newIdentNode("getStr")
    )
  )
  for element in elements:
    result.add nnkOfBranch.newTree(
      newLit(element),
      nnkStmtList.newTree(
        nnkCall.newTree(
          newIdentNode("parse_" & element),
          newIdentNode("element")
        )
      )
    )
  result.add nnkElse.newTree(
    quote do:
      raise newException(Exception, "not found tag")
  )

macro mumlDeserializer* (customElements: varargs[untyped]): untyped =
  var
    elements = @BuiltInElements
    elementsAST = nnkBracket.newTree()
  for customElement in customElements:
    elements.add $customElement
  for element in elements:
    elementsAST.add newLit($element)

  let
    procName = newIdentNode("deserialize")
    elementIdent = newIdentNode("element")
    definedElementsIdent = newIdentNode("DefinedElements")
    caseOfApplyParser = caseOfApplyParserAST(elements)

  result = quote do:
    const `definedElementsIdent`* = `elementsAST`
    proc `procName`* (muml: mumlNode): seq[mumlRootElement] =
      for `elementIdent` in muml.contents:
        var mumlObj = `caseOfApplyParser`
        mumlObj.id = genUuid()
        result.add mumlObj
