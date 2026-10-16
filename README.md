# GQA FFmpeg Builds

This repository distributes GQA's custom, unofficial FFmpeg builds for GQA Flight Recorder. GQA maintains a small, reproducible Windows runtime for Flight Recorder's capture and replay workflows, following its approved Zero-Royalty Technical Architecture. The proprietary Flight Recorder application is not included here.

## Current release

The current release is FFmpeg 9.0.2 with libopus 1.6.1: Windows x64 shared libraries under LGPL 2.1-or-later. It provides Opus audio and hardware H.264, HEVC and AV1 encoder interfaces through AMD AMF, NVIDIA NVENC and Intel QSV.

The runtime contains no AAC encoder or decoder and no software H.264, HEVC or AV1 encoder or decoder. Its selected components support Flight Recorder's capture, replay, screenshot, probing and media-packaging paths. Hardware encoder availability depends on the installed GPU and driver.

Open the [immutable October 16, 2026 release](https://github.com/gqa-gmbh/GQA-FFmpeg-Builds/releases/tag/ffmpeg-9.0.2-gqa-opus-20261016) to download the runtime and its matching source/build package:

| Asset | Download | SHA-256 |
| --- | --- | --- |
| Runtime | [ffmpeg-gqa-minimal-lgpl-opus-9.0.2-libopus-1.6.1-win64-shared-20261016.zip](https://github.com/gqa-gmbh/GQA-FFmpeg-Builds/releases/download/ffmpeg-9.0.2-gqa-opus-20261016/ffmpeg-gqa-minimal-lgpl-opus-9.0.2-libopus-1.6.1-win64-shared-20261016.zip) | 30651d5f9c03991584181730db94a85a2343ef1649168658552c7103342eeb75 |
| Corresponding source and build materials | [source-package-FFmpeg-Opus-LGPL-20261016.zip](https://github.com/gqa-gmbh/GQA-FFmpeg-Builds/releases/download/ffmpeg-9.0.2-gqa-opus-20261016/source-package-FFmpeg-Opus-LGPL-20261016.zip) | 701d00b7219e91d061a8645d99fc2601d9fcbd5188674d7a9a566f877c7184af |
| Release manifest | [RELEASE-MANIFEST.json](https://github.com/gqa-gmbh/GQA-FFmpeg-Builds/releases/download/ffmpeg-9.0.2-gqa-opus-20261016/RELEASE-MANIFEST.json) | 9d20f089332743e04144eff711634d959674c1853c4c474e456398f090ee7097 |
| Checksums | [CHECKSUMS.sha256](https://github.com/gqa-gmbh/GQA-FFmpeg-Builds/releases/download/ffmpeg-9.0.2-gqa-opus-20261016/CHECKSUMS.sha256) | f435a711f7c163e3d8f5ca664ef0289d7ac0e1aadcd619b860d4bb85bcae1a99 |

Verify a downloaded file against the release page or checksum list with PowerShell:

    Get-FileHash .\ffmpeg-gqa-minimal-lgpl-opus-9.0.2-libopus-1.6.1-win64-shared-20261016.zip -Algorithm SHA256

The release manifest records package identity and build evidence. The checksum file covers the runtime, source package and manifest; the release page also publishes each asset's SHA-256 digest.

## Source and attribution

The matching source/build ZIP contains the pinned source inputs, build recipe and configuration, toolchain notes, and license and attribution materials needed to reproduce and inspect this runtime. Use that archive for rebuilding this specific package; GitHub's automatically generated source snapshots of this repository are not the corresponding source for the FFmpeg runtime.

FFmpeg is developed by the FFmpeg project; this is an unofficial GQA build. FFmpeg and third-party license notices are included with the runtime and source package. Review and retain those notices when redistributing the build.

## Previous releases

The [October 15, 2026 release](https://github.com/gqa-gmbh/GQA-FFmpeg-Builds/releases/tag/ffmpeg-9.0.2-gqa-20261015) is retained as a historical, superseded build. Its configuration does not describe the current Opus release.
