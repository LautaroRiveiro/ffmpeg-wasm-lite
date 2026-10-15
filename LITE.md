# ffmpeg-core lite

Build reducido de [ffmpeg.wasm](https://github.com/ffmpegwasm/ffmpeg.wasm) (v12.15) con solo lo necesario para aplanar una playlist HLS (H.264 + AAC en `.ts`) a MP4 sin recodificar el video, mezclando una música de fondo MP3.

## Licencia

- El binario (`ffmpeg-core.wasm`) contiene [FFmpeg](https://ffmpeg.org) `n5.1.4`, compilado **sin** `--enable-gpl` ni `--enable-nonfree` y sin bibliotecas externas: se distribuye bajo **LGPL 2.1 o posterior** (ver `COPYING.LGPLv2.1` en el artefacto).
- La configuración exacta del build queda en `BUILD_CONFIG.txt`, dentro del artefacto.
- El código JS y los scripts de ffmpeg.wasm son MIT (ver `LICENSE`).

## Componentes

| Tipo | Habilitados |
|---|---|
| Protocolos | `file`, `pipe` |
| Demuxers | `concat`, `mpegts`, `mp3` |
| Muxers | `mp4` |
| Parsers | `h264`, `aac`, `mpegaudio` |
| Decoders | `aac`, `h264` (solo para analizar el stream: el video se copia), `mp3`, `mp3float` |
| Encoders | `aac` |
| BSFs | `aac_adtstoasc`, `extract_extradata`, `null` |
| Filtros | `amix`, `aresample`, `aformat`, `anull`, `abuffer`, `abuffersink`, `null`, `buffer`, `buffersink` |

Para agregar un componente, sumarlo en la etapa `ffmpeg-builder` del `Dockerfile`.

## Build

- **GitHub Actions**: cada push a `main` (o "Run workflow" a mano) compila y sube el artefacto `ffmpeg-core-lite`.
- **Local** (Docker Desktop corriendo): `./build-lite.sh`. Deja el resultado en `packages/core/dist/{esm,umd}`.

El build falla si `config.h` termina con GPL o nonfree habilitado.
