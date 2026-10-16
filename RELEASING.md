# Publishing an FFmpeg release

This is the authoritative runbook for publishing an already built and verified GQA FFmpeg distribution. It does not build FFmpeg. Keep the runtime, matching source/build archive, manifest and checksum file from one distribution together.

The October 16, 2026 release is the current published example. Its immutable tag is ffmpeg-9.0.2-gqa-opus-20261016. Do not run a publish against that tag or replace its assets or user-edited description.

## Prerequisites

- Windows PowerShell 7, Git, and GitHub CLI (gh). Check the installed CLI with gh version.
- An authenticated GitHub CLI session with write permission to gqa-gmbh/GQA-FFmpeg-Builds. Check with gh auth status and gh repo view gqa-gmbh/GQA-FFmpeg-Builds --json nameWithOwner,viewerPermission,defaultBranchRef. The account must have WRITE, MAINTAIN or ADMIN permission.
- A local clone of this repository on its existing default branch, with origin pointing to gqa-gmbh/GQA-FFmpeg-Builds.
- A verified distribution directory with RELEASE-MANIFEST.json, CHECKSUMS.sha256, the runtime ZIP named by runtimeArtifact in the manifest, and the matching source/build ZIP named by sourceArtifact. Keep human-authored release notes in a separate file.

Install or update GitHub CLI using GitHub's supported distribution, then authenticate with gh auth login --hostname github.com --git-protocol https. Do not read tokens from a credential store, print credentials, reuse a browser session, or use Computer Use. The publishing helper checks CLI availability, authentication, repository identity and permission without displaying authentication output.

Before publishing, review the manifest's FFmpeg revision, dependency versions, configuration, capabilities, and artifact identities. Verify that the source ZIP corresponds to that runtime. Do not rebuild or mix artifacts while preparing a release. The helper checks the manifest's runtime and source hashes and sizes, validates the checksum list against those files and the manifest, and publishes only those three files plus CHECKSUMS.sha256.

## Prepare release notes

Start from RELEASE-TEMPLATE.md and write release-specific content by hand. Purpose must be the first heading and explain why this version exists. Complete all six required sections in the template. Do not mechanically turn a component inventory into release prose.

Review the current release text and public README before changing either. Preserve user-edited release descriptions. If a published release is immutable, leave it intact; never replace the tag or release to work around immutability.

## Validate and publish

The helper's default mode is read-only validation. It checks local files and hashes, notes structure, GitHub CLI authentication, repository permission, and whether the tag or release already exists. It makes no GitHub changes.

For example, first validate a prepared distribution and notes:

    $distribution = "D:\path\to\distribution"
    $manifest = Get-Content (Join-Path $distribution "RELEASE-MANIFEST.json") -Raw | ConvertFrom-Json
    $tag = $manifest.proposedTag
    $notes = "D:\path\to\release-notes.md"
    pwsh -NoProfile -File .\scripts\Publish-Release.ps1 -DistributionDirectory $distribution -ReleaseTag $tag -ReleaseNotesPath $notes

Review every reported identity and hash. The manifest tag must match the requested tag. The notes must begin with Purpose, followed by Changes, Capabilities, Downloads, Build and licensing, and Technical limitations. Purpose must contain release-specific prose, not an empty section or the template prompt.

Only after the validation report and notes are reviewed, pass the explicit -Publish option:

    pwsh -NoProfile -File .\scripts\Publish-Release.ps1 -DistributionDirectory $distribution -ReleaseTag $tag -ReleaseNotesPath $notes -Publish

The helper repeats preflight checks, refuses an existing tag or release, creates a draft release on the repository's current default branch, attaches the four intended assets, verifies the draft inventory and GitHub-reported SHA-256 digests, and publishes it. It then checks that the release is public, downloads the published assets with GitHub CLI into a new temporary directory, and independently checks the exact asset inventory, lengths and SHA-256 values. It removes only that helper-created verification directory.

The underlying supported CLI workflow is gh release create with the version tag, four asset paths, --draft, --notes-file and --target set to the current default branch; gh release view to inspect the draft; gh release edit with --draft=false to publish; then gh release view and gh release download to verify it. The helper performs these operations in that order and is the preferred procedure.

The create operation may create a Git tag at the selected default branch if the tag does not already exist. The helper checks for an existing tag first and aborts on any existing tag or release. If another publisher creates the tag after that check, GitHub CLI fails safely rather than overwriting it.

The helper returns 0 for successful validation or completed publication and verification, 2 for preflight/package/notes errors, 3 when the tag or release already exists, 4 when draft creation, asset upload or publication fails, and 5 when a published release cannot be independently verified. For codes 4 or 5, inspect the remote state before retrying.

## Update and verify the public README

README publication is part of release completion. After release publication and asset verification:

1. Update the current-release section with the immutable release URL, exact runtime and source asset URLs, manifest and checksum links, and verified SHA-256 values. Keep a concise link to prior releases as historical; do not remove their assets.
2. Review the complete diff, commit the README update on the existing default branch, and push that branch. Do not create a release branch or push Flight Recorder.
3. Independently verify the release text and asset list with gh release view <tag> --repo gqa-gmbh/GQA-FFmpeg-Builds --json tagName,name,body,isDraft,isImmutable,assets. Verify the pushed README blob with gh api repos/gqa-gmbh/GQA-FFmpeg-Builds/contents/README.md --jq .sha and compare it with git hash-object README.md. Recheck that README links use the exact immutable release tag and asset filenames.
4. Report the release URL, asset names and hashes, public README commit, and any limitation. Do not call the release complete until both the release and README are publicly verifiable.

## Retry and recovery

- Missing CLI, failed authentication, or insufficient permission: stop before publication. Install gh or use gh auth login, then verify identity and repository permission. Do not access credentials by another route.
- Existing tag or release: stop. The helper will not overwrite it. Inspect the public state and choose a new, approved version tag only when the package represents a genuinely new release. Never delete or recreate a published release as automatic recovery.
- Draft created with partial assets: do not rerun -Publish. Inspect the draft with gh release view. Keep it as a draft while determining which assets are present. A maintainer may upload only missing, hash-verified files with gh release upload; do not use --clobber. Verify the exact four-file inventory and hashes before publishing. If an incorrect asset must be removed, stop for explicit maintainer review rather than deleting it automatically.
- Hash or inventory mismatch: do not publish. Preserve the draft and local package, identify the mismatched file, and prepare a corrected distribution under a new versioned tag if needed. Do not alter an already published asset.
- Release published but README update or push failed: leave the release intact. Finish and verify the README change, then push it. Until both are verified, report the release as published but the repository update as incomplete.
- Public release cannot be verified or downloaded: do not republish, delete, or replace it. Check gh authentication, connectivity, release visibility, asset names and digests; retry read-only verification after resolving the cause. Escalate if the state remains ambiguous.
- Existing draft or partially created tag: the normal helper intentionally refuses to continue because a retry could overwrite or misrepresent a release. Review it and follow the controlled draft recovery above.

## Distribution and project boundaries

Keep upstream FFmpeg and third-party attribution, notices, and corresponding source/build materials with each runtime. Do not upload internal assessments. Follow GQA's approved Zero-Royalty Technical Architecture as settled project direction; this runbook is not a request to reopen that decision. Do not publish Flight Recorder application artifacts or change its recording implementation here.
