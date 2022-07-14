import ffmpeg
import types

type
  Scaler* = object
    context: ptr SwsContext

  ScalerProp* = object
    width, height: int32
    format: AVPixelFormat
    filter: ptr SwsFilter

proc init* (_: typedesc[Scaler], srcProp, destProp: ScalerProp): Scaler =
  result = Scaler()
  result.context = sws_getContext(
    srcProp.width, srcProp.height, srcProp.format,
    destProp.width, destProp.height, destProp.format,
    SWS_BICUBIC, srcProp.filter, destProp.filter, nil
  )

proc init* (_: typedesc[ScalerProp], width, height: int32, format: VideoFrameFormat, filter: ptr SwsFilter = nil): ScalerProp =
  result = ScalerProp()
  result.width = width
  result.height = height
  result.format = cast[AVPixelFormat](format)
  result.filter = filter

proc scale* (scaler: Scaler, src_frame, dest_frame: VideoFrame) =
  discard
  # discard sws_scale(
  #   scaler.context,
  #   src_frame.
  # )