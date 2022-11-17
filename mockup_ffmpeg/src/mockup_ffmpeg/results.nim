import std/macros

# {.experimental: "strictCaseObjects".}
{.experimental: "caseStmtMacros".}

type
  ResultKind* = enum
    rOk, rErr

  Result* [T, E] = object
    case kind*: ResultKind
    of rOk:
      ok*: T
    else:
      err*: E

proc ok* [T, E] (_: typedesc[Result[T, E]], value: T): Result[T, E] =
  result = Result[T, E](kind: rOk, ok: value)
  
proc err* [T, E] (_: typedesc[Result[T, E]], err: E): Result[T, E] =
  result = Result[T, E](kind: rErr, err: err)

proc ok2* [T, E] (res: Result[T, E], value: T): Result[T, E] =
  result = Result[T, E](kind: ResultKind.rOk, ok: value)

proc err2* [T, E] (res: Result[T, E], err: E): Result[T, E] =
  result = Result[T, E](kind: ResultKind.rErr, err: err)

template ok* (value: untyped): untyped =
  result.ok2(value)

template err* (err: untyped): untyped =
  result.err2(err)

proc unwrap* [T, E] (res: Result[T, E]): T =
  if res.kind == rOk:
    result = res.ok
  else:
    raise newException(Defect, "")

proc error* [T, E] (res: Result[T, E]): E =
  if res.kind == rErr:
    result = res.err
  else:
    raise newException(Defect, "")

macro `case`* (ast: Result): untyped =
  result = ast
  result[0] = nnkStmtListExpr.newTree(
    nnkLetSection.newTree(
      nnkIdentDefs.newTree(
        newIdentNode("resInCaseStatement"),
        newEmptyNode(),
        result[0],
      )
    ),
    nnkDotExpr.newTree(
      newIdentNode("resInCaseStatement"),
      newIdentNode("kind")
    )
  )
  for i in 1..2:
    if $result[i][0][0] == "ok":
      result[i][1].insert(0,
        nnkLetSection.newTree(
          nnkIdentDefs.newTree(
            newIdentNode(result[i][0][1].strVal),
            newEmptyNode(),
            nnkCall.newTree(
              nnkDotExpr.newTree(
                newIdentNode("resInCaseStatement"),
                newIdentNode("unwrap")
              )
            )
          )
        )
      )
      result[i][0] = newIdentNode("rOk")
    elif $result[i][0][0] == "err":
      result[i][1].insert(0,
        nnkLetSection.newTree(
          nnkIdentDefs.newTree(
            newIdentNode(result[i][0][1].strVal),
            newEmptyNode(),
            nnkCall.newTree(
              nnkDotExpr.newTree(
                newIdentNode("resInCaseStatement"),
                newIdentNode("error")
              )
            )
          )
        )
      )
      result[i][0] = newIdentNode("rErr")

template `?`* [T, E] (res: Result[T, E]): untyped =
  let r = res
  if r.kind == rOk:
    r.ok
  else:
    return err(r.err)
