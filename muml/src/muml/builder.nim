import std/[random, macros, json, strutils]
import builtin/commonTypes, utils, parserAST
export json, parseEnum, removeDoubleQuotation

proc serialize (typedescNimNode: NimNode, rootType: bool): JsonNode {.compileTime.}

proc parseTypeName (typeNameAST: NimNode): JsonNode {.compileTime.} =
  expectKind(typeNameAST, nnkSym)
  const SupportTypes = [
    "int", "int8", "int16", "int32", "int64",
    "uint", "uint8", "uint16", "uint32", "uint64",
    "char", "string", "bool", "float", "float32", "float64"
  ]
  if $typeNameAST in SupportTypes:
    result = %* $typeNameAST
  else:
    result = serialize(typeNameAST, false)

proc serializeObject (prevJson: JsonNode, typeImplFields: NimNode): JsonNode =
  result = prevJson
  for typeImplField in typeImplFields:
    let fieldName = case typeImplField[0].kind
                    of nnkIdent: $typeImplField[0]
                    of nnkPostfix: $typeImplField[0][1]
                    else:
                      error("unsupported type")
                      ""
    expectKind(typeImplField[1], {nnkSym, nnkBracketExpr})
    case typeImplField[1].kind
    of nnkSym:
      result[fieldName] = parseTypeName(typeImplField[1])
    of nnkBracketExpr:
      expectLen(typeImplField[1], 2)
      expectIdent(typeImplField[1][0], "Animation")
      result["@" & fieldName] = parseTypeName(typeImplField[1][1])
    else: discard

proc serialize (typedescNimNode: NimNode, rootType: bool): JsonNode {.compileTime.} =
  result = %*{}
  let typeImpl = typedescNimNode.getImpl

  if rootType:
    expectKind(typeImpl[2], nnkRefTy)
    expectKind(typeImpl[2][0], nnkObjectTy)

  result["type"] = %* $typedescNimNode
  if typeImpl[2].kind == nnkObjectTy:
    let typeImplFields = typeImpl[2][2]
    result = serializeObject(result, typeImplFields)
  elif typeImpl[2][0].kind == nnkObjectTy:
    let typeImplFields = typeImpl[2][0][2]
    result = serializeObject(result, typeImplFields)
  elif typeImpl[2].kind == nnkEnumTy:
    result = %* ("enum:" & $typedescNimNode)

var randObject {.compileTime.} = initRand(20031030)

proc generateParser (prevAST: NimNode, keyValueID: int, deserializeMap: JsonNode): NimNode {.compileTime.} =
  ## of節以降を生成する、ネストしたオブジェクトがある場合はfor文、case節までを生成する
  result = prevAST

  for deserializeKey, deserializeVal in deserializeMap.pairs:
    if deserializeKey == "type":
      continue

    if deserializeKey[0] == '@':
      ### アニメーション
      if deserializeVal.kind == JString:
        let typeName = deserializeVal.getStr
        if typeName == "int":
          result.add getIntSequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "int8":
          result.add getInt8SequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "int16":
          result.add getInt16SequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "int32":
          result.add getInt32SequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "int64":
          result.add getInt64SequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "uint":
          result.add getUintSequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "uint8":
          result.add getUint8SequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "uint16":
          result.add getUint16SequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "uint32":
          result.add getUint32SequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "uint64":
          result.add getUint64SequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "float":
          result.add getFloatSequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "float32":
          result.add getFloat32SequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "float64":
          result.add getFloat64SequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "bool":
          result.add getBoolSequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "char":
          result.add getCharSequenceParserAST(deserializeKey[1..^1], keyValueID)
        elif typeName == "string":
          result.add getStringSequenceParserAST(deserializeKey[1..^1], keyValueID)
        else:
          error("unsupported type")
      
      elif deserializeVal.kind == JObject:
        ### ネストしたオブジェクトのためにforとcaseを生成する
        let
          nextKeyValueID = randObject.rand(1000000)
          currentResultElement = newIdentNode("resultElement_" & $keyValueID)
          nextResultElement = newIdentNode("resultElement_" & $nextKeyValueID)
          nextKey = newIdentNode("key_" & $nextKeyValueID)
          nextVal = newIdentNode("val_" & $nextKeyValueID)
          currentVal = newIdentNode("val_" & $keyValueID)
          field = newIdentNode(deserializeKey[1..^1])
          nextObjectName = newIdentNode(deserializeVal["type"].getStr.removeDoubleQuotation)
        
        result.add nnkOfBranch.newTree(
          newLit(deserializeKey[1..^1]),
          quote do:
            for jsonArrayElement in `currentVal`:
              var `nextResultElement` = `nextObjectName`()
              for `nextKey`, `nextVal` in pairs(jsonArrayElement):
                discard
        )
        result[^1][^1][^1][^1][^1][0] = nnkCaseStmt.newTree(nextKey)
        result[^1][^1][^1][^1][^1][^1] = generateParser(result[^1][^1][^1][^1][^1][0], nextKeyValueID, deserializeVal)
        result[^1][^1][^1].add quote do:
          `currentResultElement`.`field`.add `nextResultElement`

    elif deserializeVal.kind == JString:
      ### of節を生成する
      let typeName = deserializeVal.getStr

      if typeName == "int":
        result.add getIntParserAST(deserializeKey, keyValueID)
      elif typeName == "int8":
        result.add getInt8ParserAST(deserializeKey, keyValueID)
      elif typeName == "int16":
        result.add getInt16ParserAST(deserializeKey, keyValueID)
      elif typeName == "int32":
        result.add getInt32ParserAST(deserializeKey, keyValueID)
      elif typeName == "int64":
        result.add getInt64ParserAST(deserializeKey, keyValueID)
      elif typeName == "uint":
        result.add getUintParserAST(deserializeKey, keyValueID)
      elif typeName == "uint8":
        result.add getUint8ParserAST(deserializeKey, keyValueID)
      elif typeName == "uint16":
        result.add getUint16ParserAST(deserializeKey, keyValueID)
      elif typeName == "uint32":
        result.add getUint32ParserAST(deserializeKey, keyValueID)
      elif typeName == "uint64":
        result.add getUint64ParserAST(deserializeKey, keyValueID)
      elif typeName == "float":
        result.add getFloatParserAST(deserializeKey, keyValueID)
      elif typeName == "float32":
        result.add getFloat32ParserAST(deserializeKey, keyValueID)
      elif typeName == "float64":
        result.add getFloat64ParserAST(deserializeKey, keyValueID)
      elif typeName == "bool":
        result.add getBoolParserAST(deserializeKey, keyValueID)
      elif typeName == "char":
        result.add getCharParserAST(deserializeKey, keyValueID)
      elif typeName == "string":
        result.add getStringParserAST(deserializeKey, keyValueID)
      elif typeName.len >= 4 and typeName[0..4] == "enum:":
        result.add getEnumParserAST(typeName[5..^1], deserializeKey, keyValueID)
      else:
        error("unsupported type")
    
    elif deserializeVal.kind == JObject:
      ### ネストしたオブジェクトのためにforとcaseを生成する
      let
        nextKeyValueID = randObject.rand(1000000)
        currentResultElement = newIdentNode("resultElement_" & $keyValueID)
        nextResultElement = newIdentNode("resultElement_" & $nextKeyValueID)
        nextKey = newIdentNode("key_" & $nextKeyValueID)
        nextVal = newIdentNode("val_" & $nextKeyValueID)
        currentVal = newIdentNode("val_" & $keyValueID)
        field = newIdentNode(deserializeKey)
        nextObjectName = newIdentNode(deserializeVal["type"].getStr.removeDoubleQuotation)
      
      result.add nnkOfBranch.newTree(
        newLit(deserializeKey),
        quote do:
          var `nextResultElement` = `nextObjectName`()
          for `nextKey`, `nextVal` in pairs(`currentVal`):
            discard
      )
      result[^1][^1][^1][^1][0] = nnkCaseStmt.newTree(nextKey)
      result[^1][^1][^1][^1][^1] = generateParser(result[^1][^1][^1][^1][0], nextKeyValueID, deserializeVal)
      result[^1][^1].add quote do:
        `currentResultElement`.`field` = `nextResultElement`

proc generateParserProc (procName, typeName: NimNode, json: JsonNode): NimNode {.compileTime.} =
  let
    keyValueID = randObject.rand(1000000)
    key = ident("key_" & $keyValueID)
    val = ident("val_" & $keyValueID)
    resultElement = ident("resultElement_" & $keyValueID)

  result = quote do:
    proc `procName`* (muml: JsonNode): mumlRootElement =
      var `resultElement` = `typeName`()
      for `key`, `val` in muml.pairs:
        discard
  
  # prevASTの`discard`文を置換
  result[^1][^1][^1] = nnkCaseStmt.newTree(
    newIdentNode("key_" & $keyValueID)
  )
  
  result[^1][^1][^1] = generateParser(result[^1][^1][^1], keyValueID, json)

  result[^1].add nnkAsgn.newTree(
    newIdentNode("result"),
    newIdentNode("resultElement_" & $keyValueID)
  )

macro mumlBuilder* (mumlElement: typedesc): untyped =
  let
    typeName = ident($mumlElement)
    procName = ident("parse_" & $mumlElement)
    serializedMumlElement = serialize(mumlElement, true)
  result = generateParserProc(procName, typeName, serializedMumlElement)
