import tables, uuids, options
import clips

type
  mTimeLine* = object
    timelineTable: Table[uint64, mLayer]
  
  mLayer* = object
    clips: Table[UUID, mClip]

proc TimeLine* (): mTimeLine =
  ## タイムラインオブジェクトを生成します。
  runnableExamples:
    var tl = TimeLine()

  result = mTimeLine(timelineTable: tables.initTable[uint64, mLayer]())

proc `[]`* (timeline: var mTimeLine, index: uint64): var mLayer =
  if not timeline.timelineTable.hasKey(index):
    timeline.timelineTable[index] = mLayer(clips: initTable[UUID, mClip]())
  result = timeline.timelineTable[index]

proc canRewriteLayer (layer: mLayer, judged_clip: mClip): bool =
  result = true
  for key, clip in layer.clips.pairs:
    var
      fStart = clip.start_frame
      fEnd = fStart + clip.frame_width
      judgedFStart = judged_clip.start_frame
      judgedFEnd = judgedFStart + judged_clip.frame_width
    
    if fStart < judgedFStart and judgedFStart < fEnd:
      return false
    
    if fStart < judgedFEnd and judgedFEnd < fEnd:
      return false

proc push* (layer: var mLayer, new_clip: mClip): Option[UUID] =
  ## タイムラインオブジェクトにクリップを追加します。
  ## 同じフレームにオブジェクトを重複して追加することはできません。
  ## 追加に成功した場合はクリップの識別番号を、失敗した場合は ``none(UUID)`` を返します。
  runnableExamples:
    import clips
    var
      tl = TimeLine()
      video_uuid = tl[1].push(Clip())

  if layer.canRewriteLayer(new_clip):
    let uuid = genUUID()
    layer.clips[uuid] = new_clip
    result = some(uuid)
  else:
    result = none(UUID)

proc destory* (layer: var mLayer, uuid: UUID): bool =
  if layer.clips.hasKey(uuid):
    layer.clips.del(uuid)
    result = true
  else:
    result = false

proc update* (layer: var mLayer, clip_uuid: UUID, update_clip: mClip): bool =
  result = false
  if layer.clips.hasKey(clip_uuid):
    var poped_clip: mClip
    if layer.clips.pop(clip_uuid, poped_clip):
      if layer.canRewriteLayer(update_clip):
        layer.clips[clip_uuid] = update_clip
        result = true
      else:
        layer.clips[clip_uuid] = poped_clip
