# syntax=docker/dockerfile:1.7-labs

# ffmpeg.wasm "lite": solo lo necesario para aplanar una playlist HLS a MP4
# sin recodificar el video y mezclando una música de fondo.
#
#   ffmpeg -f concat -safe 0 -i list.txt -i music.mp3
#     -c:v copy -filter_complex "[0:a][1:a]amix=...[aout]"
#     -map 0:v -map [aout] -c:a aac -movflags +faststart out.mp4
#
# Licencia: LGPL 2.1+. No se compila con --enable-gpl ni --enable-nonfree ni
# con ninguna biblioteca externa (x264, x265, lame...). La etapa
# `ffmpeg-builder` corta el build si config.h dice otra cosa.
#
# Basado en ffmpegwasm/ffmpeg.wasm v12.15 (MIT).

# Base emsdk image with environment variables.
FROM emscripten/emsdk:3.1.40 AS emsdk-base
ARG EXTRA_CFLAGS
ARG EXTRA_LDFLAGS
ARG FFMPEG_ST
ARG FFMPEG_MT
ENV INSTALL_DIR=/opt
# We cannot upgrade to n6.0 as ffmpeg bin only supports multithread at the moment.
ENV FFMPEG_VERSION=n5.1.4
ENV CFLAGS="-I$INSTALL_DIR/include $CFLAGS $EXTRA_CFLAGS"
ENV CXXFLAGS="$CFLAGS"
ENV LDFLAGS="-L$INSTALL_DIR/lib $LDFLAGS $CFLAGS $EXTRA_LDFLAGS"
ENV EM_PKG_CONFIG_PATH=$EM_PKG_CONFIG_PATH:$INSTALL_DIR/lib/pkgconfig:/emsdk/upstream/emscripten/system/lib/pkgconfig
ENV EM_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake
ENV PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$EM_PKG_CONFIG_PATH
ENV FFMPEG_ST=$FFMPEG_ST
ENV FFMPEG_MT=$FFMPEG_MT
RUN apt-get update && \
      apt-get install -y pkg-config

# Base ffmpeg image with source code populated. Sin bibliotecas externas.
FROM emsdk-base AS ffmpeg-base
RUN embuilder build sdl2 sdl2-mt
ADD https://github.com/FFmpeg/FFmpeg.git#$FFMPEG_VERSION /src

# Build ffmpeg
#
# `--disable-everything` apaga todos los componentes y después se prende uno
# por uno lo que usa el comando de arriba:
#   - concat/mpegts: los segmentos .ts, unidos con el concat demuxer
#   - mp3: la música de fondo
#   - parsers h264/aac + decoder h264: el video NO se decodifica al convertir
#     (-c:v copy), pero sin el decoder el análisis del stream no obtiene las
#     dimensiones ("unspecified size") y el muxer mp4 no puede escribir el
#     header. Se usa solo para leer los primeros frames.
#   - extract_extradata: SPS/PPS del H.264 para el avcC del MP4
#   - aac (dec/enc) + amix/aresample/aformat: la mezcla de audio
#   - mp4: la salida
FROM ffmpeg-base AS ffmpeg-builder
COPY build/ffmpeg.sh /src/build.sh
RUN bash -x /src/build.sh \
      --disable-everything \
      --disable-network \
      --enable-protocol=file,pipe \
      --enable-demuxer=concat,mpegts,mp3 \
      --enable-muxer=mp4 \
      --enable-parser=h264,aac,mpegaudio \
      --enable-decoder=aac,h264,mp3,mp3float \
      --enable-encoder=aac \
      --enable-bsf=aac_adtstoasc,extract_extradata,null \
      --enable-filter=amix,aresample,aformat,anull,abuffer,abuffersink,null,buffer,buffersink
# Garantía de licencia: si algo prendió GPL o nonfree, el build falla acá.
RUN grep -q "#define CONFIG_GPL 0" /src/config.h && \
    grep -q "#define CONFIG_NONFREE 0" /src/config.h

# Build ffmpeg.wasm
FROM ffmpeg-builder AS ffmpeg-wasm-builder
COPY src/bind /src/src/bind
COPY src/fftools /src/src/fftools
COPY build/ffmpeg-wasm.sh build.sh
RUN mkdir -p /src/dist/umd && bash -x /src/build.sh \
      -o dist/umd/ffmpeg-core.js
RUN mkdir -p /src/dist/esm && bash -x /src/build.sh \
      -sEXPORT_ES6 \
      -o dist/esm/ffmpeg-core.js
# Lo que pide la LGPL que viaje con el binario: el texto de la licencia y la
# configuración exacta con la que se compiló.
RUN cp /src/COPYING.LGPLv2.1 /src/dist/ && \
    grep FFMPEG_CONFIGURATION /src/config.h > /src/dist/BUILD_CONFIG.txt && \
    echo "FFmpeg $FFMPEG_VERSION - https://github.com/FFmpeg/FFmpeg/tree/$FFMPEG_VERSION" >> /src/dist/BUILD_CONFIG.txt

# Export ffmpeg-core.wasm to dist/, use `docker buildx build -o . .` to get assets
FROM scratch AS exportor
COPY --from=ffmpeg-wasm-builder /src/dist /dist
