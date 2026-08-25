# Install the dsh-code-security bundle (single package since 0.2.0):
#   1. agent preset  -> ~/.dsh/.agent-presets/dsh-security (skills + scan tools)
#   2. bundle        -> `dsh plugin --profile web add <this directory>`; the
#      package declares `dsh.bundle.patch`, so `dsh plugin add` activates it as
#      a profile bundle layer automatically (gate panel + batch tools mount;
#      no manual cordis.patch.yml row needed).
# Idempotent: re-running replaces the previous copies and migrates installs of
# the two legacy packages (dsh-security-gate / dsh-security-tools) away.
#
# Run from a project checkout, or piped as one command once the repository is
# published:  irm <raw-install-url> | iex   (the script then clones the repo
# itself and re-runs from the clone).
$ErrorActionPreference = 'Stop'

$repoUrl = if ($env:DSH_CODE_SECURITY_REPO_URL) { $env:DSH_CODE_SECURITY_REPO_URL } else { 'https://github.com/ihuajiu/dsh-code-security' }
$profileName = if ($env:DSH_PROFILE) { $env:DSH_PROFILE } else { 'web' }

$scriptPath = $MyInvocation.MyCommand.Path
$src = if ($scriptPath) { Split-Path -Parent $scriptPath } else { '' }
$hasPayload = $src -and (Test-Path (Join-Path $src 'preset\agent.cordis.yml')) -and (Test-Path (Join-Path $src 'index.js'))
$dsh = Join-Path $env:USERPROFILE '.dsh'

if (-not $hasPayload) {
  # Piped mode: fetch the project into a PERSISTENT cache dir first, then
  # re-run this installer from the clone (`dsh plugin add` installs a file:
  # dependency whose junction points at the clone — removing it would break
  # the next `dsh` boot). No `exit`: with `irm ... | iex` the body runs in the
  # caller's session.
  if ($repoUrl -match '<owner>') {
    Write-Error 'install.ps1 must be run from the project checkout, or set DSH_CODE_SECURITY_REPO_URL to the published repository URL.'
    return
  }
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error 'git is required for the piped install — install git (https://git-scm.com) and retry.'
    return
  }
  $cacheDir = Join-Path $dsh 'cache\dsh-code-security'
  if (Test-Path $cacheDir) { Remove-Item $cacheDir -Recurse -Force }
  New-Item -ItemType Directory -Path (Split-Path $cacheDir -Parent) -Force | Out-Null
  Write-Host "Fetching $repoUrl -> $cacheDir ..." -ForegroundColor Cyan
  git clone --depth 1 "$repoUrl" "$cacheDir"
  if ($LASTEXITCODE -ne 0) {
    Write-Error "git clone failed (exit $LASTEXITCODE) — check the repository URL and network access."
    return
  }
  & (Join-Path $cacheDir 'install.ps1') @args
  $global:LASTEXITCODE = $LASTEXITCODE
  return
}

# ── 1. agent preset ─────────────────────────────────────────────────────────
$presetDest = Join-Path $dsh '.agent-presets\dsh-security'
Write-Host "Installing dsh-security preset to $presetDest" -ForegroundColor Cyan
if (Test-Path $presetDest) { Remove-Item $presetDest -Recurse -Force }
New-Item -ItemType Directory -Path $presetDest -Force | Out-Null
Copy-Item -Path (Join-Path $src 'preset\*') -Destination $presetDest -Recurse -Force

# ── 2. the bundle into the profile ──────────────────────────────────────────
$profileDir = Join-Path $dsh ("profiles\" + $profileName)
if (Test-Path (Join-Path $profileDir 'package.json')) {
  # Migrate legacy two-package installs out of the way first (best effort).
  foreach ($legacy in @('dsh-security-gate', 'dsh-security-tools')) {
    Push-Location $profileDir
    try { & 'dsh' plugin --profile $profileName remove $legacy *> $null } catch {} finally { Pop-Location }
  }
  Write-Host "Installing dsh-code-security bundle into profile $profileName" -ForegroundColor Cyan
  Push-Location $profileDir
  try {
    & 'dsh' plugin --profile $profileName add (Join-Path $src '.')
    if ($LASTEXITCODE -ne 0) { throw "dsh plugin add failed with exit code $LASTEXITCODE" }
  } finally { Pop-Location }
} else {
  Write-Host "profile '$profileName' not found — skip bundle install (preset installed only)." -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Done. Next steps:' -ForegroundColor Green
Write-Host ('  1. Restart dsh ' + $profileName + ' so the gate loads (composition changes apply at boot).')
Write-Host '  2. New DSH session -> pick the "安全审计模式" preset (id: dsh-security) for skills + model-based audits.'
Write-Host '  3. The gate auto-audits newly installed plugins with the harness model (no auth); watch <DSH_HOME>/dsh-security/summary.json.'
