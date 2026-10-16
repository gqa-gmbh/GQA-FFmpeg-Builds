# FFmpeg build repository instructions

- Read RELEASING.md before preparing or publishing a release; use RELEASE-TEMPLATE.md and put the build's purpose first.
- Treat runtime/source correspondence and SHA-256 validation as required. Update the public README whenever the current release changes.
- Preserve earlier published releases and assets. Do not overwrite release text edited by a user; verify current text before any edit.
- Use authenticated GitHub CLI without Computer Use, and independently verify the public release and README after publication.
- Follow GQA's approved codec architecture as settled project direction. Explain why a particular build exists before listing its components.
- Keep publishing documentation and tools in this repository. Do not upload internal assessments or change Flight Recorder application code.
