import tables
import muml

type
  mTimeLine* = object
    header*: mumlHeader
    content*: Table[Natural, mLayer]
    # timelineTable: Table[uint64, mLayer]
    # timelineTable: seq[mLayer]
  
  mLayer* = object
    # clips: Table[UUID, mumlObject]
    clips*: seq[mumlObject] # フレームが小さい順に並び替える

# 同じフレーム・同じレイヤにオブジェクトが重なってないかチェックする必要がある

proc add* (timeline: var mTimeLine, obj: mumlObject) =
  let layer_number = obj.layer
  if not timeline.content.hasKey(layer_number):
    timeline.content[layer_number] = mLayer(clips: @[obj])
  else:
    timeline.content[layer_number].clips.add obj