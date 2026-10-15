# GQA FFmpeg Builds

This repository accompanies an unofficial FFmpeg distribution built by GQA for its Windows game-QA recording application. FFmpeg is developed by the [FFmpeg project](https://ffmpeg.org/); GQA did not create FFmpeg, and this is not an official FFmpeg-project binary release. The proprietary GQA Flight Recorder application is not included and remains proprietary.

## Build identity

- FFmpeg 9.0.2, from upstream source revision `46d8f462eeb87ee1f704d8c44a0ee24fca471ad1`.
- Windows x64, shared-library build, configured as LGPLv3 or later.
- Minimal selection of components for the tested GQA recording, replay, probing, and media-packaging workflows; the `ipod` muxer is enabled for segmented AAC `.m4a` output.
- No FFmpeg GPL or nonfree configuration options are enabled.

## Downloads

The [version-specific GitHub Release](https://github.com/gqa-gmbh/GQA-FFmpeg-Builds/releases/tag/ffmpeg-9.0.2-gqa-20261015) provides these companion assets:

- [FFmpeg runtime](https://github.com/gqa-gmbh/GQA-FFmpeg-Builds/releases/download/ffmpeg-9.0.2-gqa-20261015/ffmpeg-gqa-minimal-lgpl-9.0.2-win64-shared-20261015.zip): `ffmpeg-gqa-minimal-lgpl-9.0.2-win64-shared-20261015.zip`
- [Matching corresponding source](https://github.com/gqa-gmbh/GQA-FFmpeg-Builds/releases/download/ffmpeg-9.0.2-gqa-20261015/source-package-FFmpeg-LGPL-20261015.zip): `source-package-FFmpeg-LGPL-20261015.zip`
- [GPLv3 license companion](https://github.com/gqa-gmbh/GQA-FFmpeg-Builds/releases/download/ffmpeg-9.0.2-gqa-20261015/COPYING.GPLv3): `COPYING.GPLv3`
- [SHA-256 checksums](https://github.com/gqa-gmbh/GQA-FFmpeg-Builds/releases/download/ffmpeg-9.0.2-gqa-20261015/SHA256SUMS.txt): `SHA256SUMS.txt`

The source ZIP is the corresponding source for this exact runtime. It contains the build recipe and configuration, required dependency sources and headers, toolchain information, and license materials. GitHub also generates “Source code” ZIP and tar.gz snapshots of this repository's Git history. Those snapshots contain this repository's README and are **not** the corresponding source for the FFmpeg runtime; use the separately listed source ZIP above.

## Licensing and notices

FFmpeg attribution: FFmpeg is a project by the FFmpeg developers. See [FFmpeg.org](https://ffmpeg.org/) and its [license and legal considerations](https://ffmpeg.org/legal.html).

The FFmpeg components and included dependencies retain their respective upstream licenses and notices. No new blanket license is applied to upstream material. Review the license and notice files included in the runtime and corresponding-source archives. The separate `COPYING.GPLv3` companion is provided with the LGPLv3 license materials; its presence does not change this build's LGPLv3-or-later configuration. The FFmpeg copyright license does not grant rights to third-party codec patents.

## Rebuilding

Use the matching source ZIP and follow the build instructions included in that package. A compatible Windows x64 build environment is required. The package's README, toolchain notes, and maintained build recipe are authoritative for rebuild steps.