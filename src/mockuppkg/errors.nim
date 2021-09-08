import tables

type
  mI18n* = enum
    mJapanese
    mEnglish

  errorMessage* = object
    msg: Table[mI18n, string]
  
  errorMessages* = seq[errorMessage]

  logMessage* = object
    msg: Table[mI18n, string]

  logMessages* = seq[logMessage]

var
  errors: errorMessages
  logs: logMessages
  language: mI18n

proc addError* (msg: Table[mI18n, string]) =
  errors.add(errorMessage(msg: msg))

proc addLog* (msg: Table[mI18n, string]) =
  logs.add(logMessage(msg: msg))

proc error* (Japanese, English: string): Table[mI18n, string] =
  result = {
    mJapanese: "[Error]: " & Japanese,
    mEnglish: "[Error]: " & English
  }.toTable

proc log* (Japanese, English: string): Table[mI18n, string] =
  result = {
    mJapanese: "[Log]: " & Japanese,
    mEnglish: "[Log]: " & English
  }.toTable