#!/usr/bin/env bash

apt-get update && apt-get install -y \
    git \
    build-essential \
    cmake \
    ffmpeg

# install ccextractor from source
git clone https://github.com/CCExtractor/ccextractor.git
cd ccextractor
mkdir build && cd build
cmake ..
make
make install

cd ../../

pip install -r requirements.txt