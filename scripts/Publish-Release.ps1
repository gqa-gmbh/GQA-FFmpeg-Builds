#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DistributionDirectory,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$')][string]$ReleaseTag,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ReleaseNotesPath,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
$script:RepoSlug = 'gqa-gmbh/GQA-FFmpeg-Builds'
$script:ExitCode = 2
$script:VerifyDirectory = $null

function Fail([string]$Message, [int]$Code = 2) {
    $script:ExitCode = $Code
    throw [System.InvalidOperationException]::new($Message)
}

function Invoke-External([string]$Path, [string[]]$Arguments) {
    $output = & $Path @Arguments 2>&1
    $code = $LASTEXITCODE
    return [pscustomobject]@{ Code = $code; Lines = @($output | ForEach-Object { $_.ToString() }) }
}

function Get-GhJson([string[]]$Arguments, [string]$Purpose, [int]$Code = 2) {
    $result = Invoke-External $script:GhPath $Arguments
    if ($result.Code -ne 0) { Fail "GitHub CLI could not $Purpose. Check connectivity, authentication and repository access." $Code }
    try { return (($result.Lines -join [Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop) }
    catch { Fail "GitHub CLI returned an unreadable response while it tried to $Purpose." $Code }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-AssetInventory($Release, [object[]]$Expected, [string]$Context) {
    $actual = @($Release.assets)
    if ($actual.Count -ne $Expected.Count) { Fail "$Context does not contain exactly the expected assets." $script:ExitCode }
    foreach ($item in $Expected) {
        $matches = @($actual | Where-Object { $_.name -ceq $item.Name })
        if ($matches.Count -ne 1) { Fail "$Context is missing $($item.Name), or contains it more than once." $script:ExitCode }
        if ([long]$matches[0].size -ne [long]$item.Length -or [string]$matches[0].digest -ine "sha256:$($item.Sha256)") {
            Fail "$Context asset $($item.Name) has a mismatched length or SHA-256." $script:ExitCode
        }
    }
}

try {
    $gh = @(Get-Command gh -CommandType Application -ErrorAction SilentlyContinue) | Select-Object -First 1
    $git = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue) | Select-Object -First 1
    if (-not $gh) { Fail 'GitHub CLI (gh) is unavailable. Install it, then retry.' }
    if (-not $git) { Fail 'Git is unavailable. Install it, then retry.' }
    $script:GhPath = $gh.Source
    $gitPath = $git.Source

    if ((Invoke-External $script:GhPath @('auth', 'status', '--hostname', 'github.com')).Code -ne 0) {
        Fail 'GitHub CLI is unauthenticated. Run gh auth login --hostname github.com --git-protocol https.'
    }
    $repo = Get-GhJson @('repo', 'view', $script:RepoSlug, '--json', 'nameWithOwner,viewerPermission,defaultBranchRef') 'inspect the target repository'
    if ([string]$repo.nameWithOwner -ine $script:RepoSlug -or [string]$repo.viewerPermission -notin @('WRITE', 'MAINTAIN', 'ADMIN')) {
        Fail 'The authenticated account cannot write to the expected repository.'
    }
    $branch = [string]$repo.defaultBranchRef.name
    if (-not $branch) { Fail 'The target repository default branch could not be read.' }

    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $remote = Invoke-External $gitPath @('-C', $root, 'remote', 'get-url', 'origin')
    $validRemotes = @(
        'https://github.com/gqa-gmbh/GQA-FFmpeg-Builds',
        'https://github.com/gqa-gmbh/GQA-FFmpeg-Builds.git',
        'git@github.com:gqa-gmbh/GQA-FFmpeg-Builds.git',
        'ssh://git@github.com/gqa-gmbh/GQA-FFmpeg-Builds.git'
    )
    if ($remote.Code -ne 0 -or $remote.Lines.Count -ne 1 -or $remote.Lines[0] -notin $validRemotes) {
        Fail 'This checkout origin is not gqa-gmbh/GQA-FFmpeg-Builds.'
    }

    if (-not (Test-Path -LiteralPath $DistributionDirectory -PathType Container)) { Fail 'The distribution directory does not exist.' }
    if (-not (Test-Path -LiteralPath $ReleaseNotesPath -PathType Leaf)) { Fail 'The release-notes file does not exist.' }
    $distribution = (Resolve-Path -LiteralPath $DistributionDirectory).Path
    $notesPath = (Resolve-Path -LiteralPath $ReleaseNotesPath).Path
    $manifestPath = Join-Path $distribution 'RELEASE-MANIFEST.json'
    $checksumsPath = Join-Path $distribution 'CHECKSUMS.sha256'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or -not (Test-Path -LiteralPath $checksumsPath -PathType Leaf)) {
        Fail 'The distribution must contain RELEASE-MANIFEST.json and CHECKSUMS.sha256.'
    }
    try { $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch { Fail 'RELEASE-MANIFEST.json is not valid JSON.' }

    $manifestTag = [string]$manifest.proposedTag
    if (-not $manifestTag -and $manifest.release) { $manifestTag = [string]$manifest.release.tag }
    if ($manifestTag -cne $ReleaseTag) { Fail 'The requested tag does not match the distribution manifest.' }
    $files = @(
        [pscustomobject]@{ Name = [string]$manifest.runtimeArtifact.fileName; Hash = [string]$manifest.runtimeArtifact.sha256; Length = [long]$manifest.runtimeArtifact.bytes },
        [pscustomobject]@{ Name = [string]$manifest.sourceArtifact.fileName; Hash = [string]$manifest.sourceArtifact.sha256; Length = [long]$manifest.sourceArtifact.bytes },
        [pscustomobject]@{ Name = 'RELEASE-MANIFEST.json'; Hash = ''; Length = -1 }
    )
    foreach ($file in $files) {
        if (-not $file.Name -or [IO.Path]::GetFileName($file.Name) -cne $file.Name) { Fail 'Manifest asset names must be safe, package-local filenames.' }
    }
    if ($files[0].Name -ceq $files[1].Name) { Fail 'Runtime and source archives must have different filenames.' }

    $sums = @{}
    foreach ($line in Get-Content -LiteralPath $checksumsPath) {
        if (-not $line.Trim()) { continue }
        $match = [regex]::Match($line, '^([0-9A-Fa-f]{64})[ \t]+\*?([^/\\]+)$')
        if (-not $match.Success -or $sums.ContainsKey($match.Groups[2].Value)) { Fail 'CHECKSUMS.sha256 contains a malformed, unsafe or duplicate entry.' }
        $sums[$match.Groups[2].Value] = $match.Groups[1].Value.ToLowerInvariant()
    }
    if ($sums.Count -ne $files.Count) { Fail 'CHECKSUMS.sha256 must list exactly the runtime, source archive and manifest.' }

    $assets = [Collections.Generic.List[object]]::new()
    foreach ($file in $files) {
        $path = Join-Path $distribution $file.Name
        if (-not $sums.ContainsKey($file.Name) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail "Required asset is missing: $($file.Name)." }
        $item = Get-Item -LiteralPath $path
        $hash = Get-Sha256 $path
        if ($hash -cne $sums[$file.Name] -or ($file.Hash -and $hash -cne $file.Hash.ToLowerInvariant())) { Fail "SHA-256 mismatch for $($file.Name)." }
        if ($file.Length -ge 0 -and [long]$item.Length -ne $file.Length) { Fail "Byte length mismatch for $($file.Name)." }
        $assets.Add([pscustomobject]@{ Name = $file.Name; Path = $path; Sha256 = $hash; Length = [long]$item.Length })
    }

    $notes = Get-Content -LiteralPath $notesPath -Raw
    $headings = @([regex]::Matches($notes, '(?m)^\s{0,3}#{1,6}\s+([^\r\n]+?)\s*#*\s*$') | ForEach-Object { $_.Groups[1].Value.Trim() })
    $required = @('Purpose', 'Changes', 'Capabilities', 'Downloads', 'Build and licensing', 'Technical limitations')
    if ($headings.Count -lt $required.Count) { Fail 'Release notes must include all six headings from RELEASE-TEMPLATE.md.' }
    for ($i = 0; $i -lt $required.Count; $i++) {
        if ($headings[$i] -cne $required[$i]) { Fail 'Purpose must be first, followed by the five required template sections.' }
    }
    $purpose = [regex]::Match($notes, '(?ms)^\s{0,3}#{1,6}\s+Purpose\s*\r?\n(.*?)(?=^\s{0,3}#{1,6}\s+|\z)').Groups[1].Value.Trim()
    if ($purpose.Length -lt 40 -or $purpose -match '(?i)^(Explain why|This section is required)') {
        Fail 'Purpose must contain release-specific prose, not a blank section or template prompt.'
    }

    Write-Output "Repository: $script:RepoSlug (permission: $($repo.viewerPermission); default branch: $branch)"
    Write-Output "Release tag: $ReleaseTag"
    foreach ($asset in $assets) { Write-Output ("Validated {0} ({1} bytes; SHA-256 {2})" -f $asset.Name, $asset.Length, $asset.Sha256) }
    Write-Output ("Validated CHECKSUMS.sha256 (SHA-256 {0})" -f (Get-Sha256 $checksumsPath))

    $releaseCheck = Invoke-External $script:GhPath @('release', 'view', $ReleaseTag, '--repo', $script:RepoSlug, '--json', 'tagName,isDraft,isImmutable')
    $releaseExists = $releaseCheck.Code -eq 0
    if (-not $releaseExists -and ($releaseCheck.Lines -join ' ') -notmatch '(?i)(release not found|could not find release|HTTP 404)') {
        Fail 'Could not determine whether the release exists. Refusing to continue.'
    }
    $tagCheck = Invoke-External $gitPath @('-C', $root, 'ls-remote', '--tags', 'origin', "refs/tags/$ReleaseTag")
    if ($tagCheck.Code -ne 0) { Fail 'Could not determine whether the tag exists on origin. Refusing to continue.' }
    if ($releaseExists -or $tagCheck.Lines.Count -gt 0) {
        if ($Publish) { Fail 'The tag or release already exists. Overwriting it is not supported.' 3 }
        Write-Output 'VALIDATION PASS: package and notes are valid; the existing remote tag/release blocks republishing. No GitHub changes were made.'
        exit 0
    }
    if (-not $Publish) {
        Write-Output 'VALIDATION PASS: package and notes are valid. No GitHub changes were made; use -Publish only after review.'
        exit 0
    }

    $script:ExitCode = 4
    $title = if ($manifest.candidateId) { [string]$manifest.candidateId } else { $ReleaseTag }
    $createArgs = @('release', 'create', $ReleaseTag) + @($assets | ForEach-Object { $_.Path }) +
        @('--repo', $script:RepoSlug, '--title', $title, '--notes-file', $notesPath, '--draft', '--target', $branch)
    if ((Invoke-External $script:GhPath $createArgs).Code -ne 0) {
        Fail 'Draft creation or upload failed. Inspect the remote tag and draft before retrying.' 4
    }
    $draft = Get-GhJson @('release', 'view', $ReleaseTag, '--repo', $script:RepoSlug, '--json', 'tagName,isDraft,assets') 'verify the uploaded draft' 4
    if ([string]$draft.tagName -cne $ReleaseTag -or -not [bool]$draft.isDraft) { Fail 'The created release is not the expected draft.' 4 }
    Assert-AssetInventory $draft $assets.ToArray() 'Draft release'
    if ((Invoke-External $script:GhPath @('release', 'edit', $ReleaseTag, '--repo', $script:RepoSlug, '--draft=false')).Code -ne 0) {
        Fail 'The draft could not be published. Inspect it before retrying.' 4
    }

    $script:ExitCode = 5
    $published = Get-GhJson @('release', 'view', $ReleaseTag, '--repo', $script:RepoSlug, '--json', 'tagName,isDraft,assets,url') 'verify the published release' 5
    if ([string]$published.tagName -cne $ReleaseTag -or [bool]$published.isDraft) { Fail 'GitHub did not report the expected release as published.' 5 }
    Assert-AssetInventory $published $assets.ToArray() 'Published release'

    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $script:VerifyDirectory = Join-Path $tempRoot ('GqaFfmpegReleaseVerify-' + [guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $script:VerifyDirectory)
    if ((Invoke-External $script:GhPath @('release', 'download', $ReleaseTag, '--repo', $script:RepoSlug, '--dir', $script:VerifyDirectory)).Code -ne 0) {
        Fail 'The release is public, but its assets could not be downloaded for independent verification.' 5
    }
    $downloaded = @(Get-ChildItem -LiteralPath $script:VerifyDirectory -File -Force)
    if ($downloaded.Count -ne $assets.Count) { Fail 'The downloaded public release asset inventory is unexpected.' 5 }
    foreach ($asset in $assets) {
        $path = Join-Path $script:VerifyDirectory $asset.Name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail "Published download is missing $($asset.Name)." 5 }
        $download = Get-Item -LiteralPath $path
        if ([long]$download.Length -ne $asset.Length -or (Get-Sha256 $path) -cne $asset.Sha256) {
            Fail "Published download does not match the expected length and SHA-256: $($asset.Name)." 5
        }
    }
    Write-Output "PUBLICATION VERIFIED: $($published.url)"
    $script:ExitCode = 0
}
catch {
    [Console]::Error.WriteLine("ERROR: {0}", $_.Exception.Message)
    exit $script:ExitCode
}
finally {
    if ($script:VerifyDirectory -and (Test-Path -LiteralPath $script:VerifyDirectory -PathType Container)) {
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        $prefix = $tempRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        $resolved = [IO.Path]::GetFullPath($script:VerifyDirectory)
        if ($resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolved) -match '^GqaFfmpegReleaseVerify-[0-9a-f]{32}$') {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
        else {
            [Console]::Error.WriteLine('WARNING: Verification files remain because the cleanup path did not pass its safety check.')
        }
    }
}
