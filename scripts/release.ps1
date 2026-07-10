[CmdletBinding()]
param(
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [string[]] $ScriptArgs
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$skipTests = $false
$noTag = $false
$newVersion = $null

function Step([string]$text) { Write-Host "`n== $text" }
function Info([string]$text) { Write-Host "  -> $text" }
function Die([string]$text) { throw "ERROR: $text" }

for ($i = 0; $i -lt $ScriptArgs.Length; $i++) {
  switch ($ScriptArgs[$i]) {
    '--skip-tests' { $skipTests = $true; continue }
    '--no-tag' { $noTag = $true; continue }
    '-h' { Write-Host 'Usage: .\scripts\release.ps1 [--skip-tests] [--no-tag] <major|minor|patch|X.Y.Z>'; return }
    '--help' { Write-Host 'Usage: .\scripts\release.ps1 [--skip-tests] [--no-tag] <major|minor|patch|X.Y.Z>'; return }
    { $_ -like '-*' } { Die "unknown option: $($_)" }
    default {
      if ($null -ne $newVersion) { Die "unexpected argument: $($ScriptArgs[$i])" }
      $newVersion = $ScriptArgs[$i]
    }
  }
}

if (-not $newVersion) { Die 'version is required' }
if ($newVersion -notmatch '^(major|minor|patch|\d+\.\d+\.\d+)$') { Die "version must be major|minor|patch or X.Y.Z" }

$packageJson = Get-Content package.json -Raw | ConvertFrom-Json
$oldVersion = $packageJson.version
if (-not $oldVersion) { Die "cannot read package.json version" }

if ($newVersion -in @('major','minor','patch')) {
  $parts = $oldVersion.Split('.')
  [int]$ma = $parts[0]
  [int]$mi = $parts[1]
  [int]$pa = $parts[2]

  $newVersion = switch ($newVersion) {
    'major' { "{0}.{1}.{2}" -f ($ma + 1), 0, 0 }
    'minor' { "{0}.{1}.{2}" -f $ma, ($mi + 1), 0 }
    default { "{0}.{1}.{2}" -f $ma, $mi, ($pa + 1) }
  }
}

if ($oldVersion -eq $newVersion) { Die "already at $newVersion" }
Write-Host "Release: $oldVersion -> $newVersion"

Step 'Pre-flight'
$branch = git branch --show-current
if ($branch -ne 'main') { Die 'must be on main' }
if (git status --porcelain) { Die 'working tree is dirty' }
git fetch --quiet origin main
if ((git rev-parse HEAD).Trim() -ne (git rev-parse origin/main).Trim()) { Die 'branch not in sync with origin/main' }

$existingTag = git tag --list "v$newVersion"
if ($existingTag) { Die "tag v$newVersion already exists" }
$existingRemoteTag = git ls-remote --tags origin "v$newVersion"
if ($existingRemoteTag) { Die "tag v$newVersion already exists on origin" }

if (-not $skipTests) {
  npm run test
  Info 'templates json validation OK'
}

Step 'Bump version'
$raw = Get-Content package.json -Raw
$updated = ($raw -replace '"version"\s*:\s*"[^"]+"', '"version": "' + $newVersion + '"')
[System.IO.File]::WriteAllText('package.json', $updated, $utf8NoBom)

Step 'Commit + push'
git add package.json scripts/validate-templates.mjs scripts/release.sh scripts/release.ps1 .github/workflows/publish-npm.yml README.md
git commit -m "chore(release): @kitsy/gutenkit v$newVersion"
git push origin main

if (-not $noTag) {
  git tag "v$newVersion"
  git push origin "v$newVersion"
}
