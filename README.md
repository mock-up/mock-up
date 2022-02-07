# mock up: A framework for developing video editing software
![](/mockup.png)

**mock up** is a framework for developing video editing software. It is also under development.

## Motivation
- It takes time to develop video editing software. No matter how great an idea you have for video editing, or how much you want to apply the HCI thesis to your video editing software, it takes a lot of preparation to create a minimal editing experience, let alone a practical one.
- The FFmpeg API is very low-level, and other image and video processing libraries are good for processing single multimedia, but none of them support the flow of developing video editing software.
- I enjoy creating environments because I want to develop a lot of video editing software that has never been done before.

## Introduction
mock up provides a video rendering engine and custom filters and animations, and by writing the video editing process through an intermediate language called muml, video editing functionality can be implemented with just a few simple front-end calls.

### Requires
- Nim >= 1.4.4
- FFmpeg
- OpenGL

### Installation

```zsh
nimble install https://github.com/mock-up/mock-up/
```

## Acknowledgments
This framework was supported by:
- Mitou Jr. 2021 (May - November 2021, [Presentation of results](https://jr.mitou.org/projects/2021/mock_up))
