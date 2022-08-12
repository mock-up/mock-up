FROM nvidia/opengl:base-ubuntu20.04
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y libx11-dev xorg-dev \
                       libglu1-mesa libglu1-mesa-dev \
                       libgl1-mesa-glx libgl1-mesa-dev \
                       libglfw3 libglfw3-dev \
                       libglew-dev \
                       ffmpeg
RUN apt-get update; apt-get install -y wget xz-utils g++; \
    wget -qO- https://deb.nodesource.com/setup_13.x | bash -; \
    apt-get install -y nodejs
RUN wget https://nim-lang.org/download/nim-1.6.6.tar.xz; \
    tar xf nim-1.6.6.tar.xz; rm nim-1.6.6.tar.xz; \
    mv nim-1.6.6 nim; \
    cd nim; sh build.sh; \
    rm -r c_code tests; \
    ln -s `pwd`/bin/nim /bin/nim
RUN apt-get update; apt-get install -y git mercurial libssl-dev
RUN cd nim; nim c koch; ./koch tools;\
    ln -s `pwd`/bin/nimble /bin/nimble;\
    ln -s `pwd`/bin/nimsuggest /bin/nimsuggest;\
    ln -s `pwd`/bin/testament /bin/testament
ENV PATH="$HOME/.nimble/bin:$PATH"