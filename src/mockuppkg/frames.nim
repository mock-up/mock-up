import ffmpeg
import nagu

type
  MockupFrame* = object
    ## 責務: AVFrameとTextureの橋渡し
    ## デコーダ(items iterator)はMockupFrameを返す
    ## エンコーダはMockFrameを受け取る
    ## ピクセルを編集することに一切関与しない、naguにAVFrameを渡すだけ
    av_frame: ptr AVFrame
    texture: Texture

# 空フレームの作成（GLClear+readPixels済）
proc initFrame* (width, height: int32): MockupFrame = discard

# コピー（別のAVFrameを持つ）
proc copy* (frame: MockupFrame): MockupFrame = discard

