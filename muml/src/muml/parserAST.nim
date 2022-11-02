import std/[macros]

func toIdent (deserializeKey: string, keyValueID: int): tuple[val, resultElement, key: NimNode] =
  result.val = newIdentNode("val_" & $keyValueID)
  result.resultElement = newIdentNode("resultElement_" & $keyValueID)
  result.key = newIdentNode(deserializeKey)

func toIdent (typeName, deserializeKey: string, keyValueID: int): tuple[typeName, val, resultElement, key: NimNode] =
  (result.val, result.resultElement, result.key) = toIdent(deserializeKey, keyValueID)
  result.typeName = newIdentNode(typeName)

proc getIntParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = getInt(`val`)
  )

proc getInt8ParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = int8(getInt(`val`))
  )

proc getInt16ParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = int16(getInt(`val`))
  )

proc getInt32ParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = int32(getInt(`val`))
  )

proc getInt64ParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = int64(getInt(`val`))
  )

proc getUintParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = uint(getInt(`val`))
  )

proc getUint8ParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = uint8(getInt(`val`))
  )

proc getUint16ParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = uint16(getInt(`val`))
  )

proc getUint32ParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = uint32(getInt(`val`))
  )

proc getUint64ParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = uint64(getInt(`val`))
  )

proc getFloatParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = getFloat(`val`)
  )

proc getFloat32ParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = float32(getFloat(`val`))
  )

proc getFloat64ParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = float64(getFloat(`val`))
  )

proc getStringParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = getStr(`val`).removeDoubleQuotation
  )

proc getCharParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      if getStr(`val`).len == 1:
        `resultElement`.`key` = getStr(`val`).removeDoubleQuotation[0]
      else:
        raise newException(Defect, "Cannot accept type string; can accept only one ASCII character.")
  )

proc getEnumParserAST* (typeName, deserializeKey: string, keyValueID: int): NimNode =
  let (typeName, val, resultElement, key) = toIdent(typeName, deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = parseEnum[`typeName`](getStr(`val`).removeDoubleQuotation)
  )

proc getBoolParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      `resultElement`.`key` = getBool(`val`)
  )

proc getFloatSequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add jsonArrayElement.getFloat
  )

proc getFloat32SequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add float32(jsonArrayElement.getFloat)
  )

proc getFloat64SequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add float64(jsonArrayElement.getFloat)
  )

proc getIntSequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add jsonArrayElement.getInt
  )

proc getInt8SequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add int8(jsonArrayElement.getInt)
  )

proc getInt16SequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add int16(jsonArrayElement.getInt)
  )

proc getInt32SequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add int32(jsonArrayElement.getInt)
  )

proc getInt64SequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add int64(jsonArrayElement.getInt)
  )

proc getUintSequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add uint(jsonArrayElement.getInt)
  )

proc getUint8SequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add uint8(jsonArrayElement.getInt)
  )

proc getUint16SequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add uint16(jsonArrayElement.getInt)
  )

proc getUint32SequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add uint32(jsonArrayElement.getInt)
  )

proc getUint64SequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add uint64(jsonArrayElement.getInt)
  )

proc getStringSequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add jsonArrayElement.getStr.removeDoubleQuotation
  )

proc getCharSequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        if getStr(`val`).len == 1:
          `resultElement`.`key`.add = getStr(`val`).removeDoubleQuotation[0]
        else:
          raise newException(Defect, "Cannot accept type string; can accept only one ASCII character.")
  )

proc getBoolSequenceParserAST* (deserializeKey: string, keyValueID: int): NimNode =
  let (val, resultElement, key) = toIdent(deserializeKey, keyValueID)
  result = nnkOfBranch.newTree(
    newLit(deserializeKey),
    quote do:
      for jsonArrayElement in `val`:
        `resultElement`.`key`.add jsonArrayElement.getBool
  )
