import ffmpeg, options

type
  mImage* = object
    frame: ptr AVFrame

proc copy (image: mImage): Option[mImage] =
  var new_frame = av_frame_alloc()
  discard av_frame_copy_props(new_frame, image.frame)
  new_frame.format = image.frame.format
  new_frame.width = image.frame.width
  new_frame.height = image.frame.height
  if av_frame_get_buffer(new_frame, 32) != 0:
    return none(mImage)
  result = some(mImage(frame: new_frame))


proc Image* (width, height: uint, format: AVPixelFormat): Option[mImage] =
  var frame = av_frame_alloc()

  if frame == nil:
    stderr.writeLine "フレームを確保できませんでした"
    return none(mImage)
  
  var
    buffer_for_save = av_image_get_buffer_size(format, width.cint, height.cint, 1.cint)
    buffer = av_malloc((buffer_for_save * sizeof(uint8)).csize_t)
    dst_data: array[4, ptr uint8]
    dst_linesize: array[4, cint]

  if buffer == nil:
    return none(mImage)
  
  var success_fill_arrays = av_image_fill_arrays(
    dst_data,
    dst_linesize,
    cast[ptr uint8](buffer),
    format,
    width.cint,
    height.cint,
    1.cint
  ).int

  if success_fill_arrays < 0:
    return none(mImage)
  
  # 応急処置
  frame.data[0..3] = dst_data
  frame.linesize[0..3] = dst_linesize

  result = some(mImage(frame: frame))