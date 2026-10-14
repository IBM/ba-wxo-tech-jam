<#
.SYNOPSIS
    Install and configure the watsonx Orchestrate ADK CLI on Windows.

.DESCRIPTION
    Automates "Appendix: ADK CLI Setup Guide" in
    lab-guides/Introduction to watsonx Orchestrate.md (sections A.1 - A.5).

    Every dependency is checked first (existence AND version); nothing is installed
    or changed if it is already in place and recent enough.

.PARAMETER WorkspaceDir
    Lab workspace directory holding the .venv. Default: .\wxo-labs

.PARAMETER EnvName
    ADK environment name. Default: trinity-lab

.PARAMETER Url
    wxO service instance URL (or env var WXO_URL). Prompted if omitted.

.PARAMETER ApiKey
    wxO API key as a SecureString (or env var WXO_API_KEY). Prompted (hidden) if omitted.

.PARAMETER SkipEnv
    Install/verify the ADK only; do not configure an environment.

.PARAMETER Yes
    Do not ask before installing Python.

.EXAMPLE
    .\labs\adk-setup\setup-adk.ps1

.EXAMPLE
    .\labs\adk-setup\setup-adk.ps1 -Url https://api.example.com/instances/abc -EnvName trinity-lab

.NOTES
    If script execution is blocked, run once in this session:
      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>
[CmdletBinding()]
param(
    [string]$WorkspaceDir = ".\wxo-labs",
    [string]$EnvName      = "trinity-lab",
    [string]$Url          = $env:WXO_URL,
    [SecureString]$ApiKey,
    [switch]$SkipEnv,
    [switch]$Yes
)

$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 may default to TLS 1.0/1.1, which python.org rejects.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

$MinPython = [version]"3.11"
$MinAdk    = [version]"2.15"
$Package   = "ibm-watsonx-orchestrate"

# ---------------------------------------------------------------- helpers
function Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; exit 1 }

# Run a native command with output shown; abort the script when it exits non-zero.
# ErrorActionPreference is relaxed because Windows PowerShell 5.1 treats native
# stderr output (e.g. pip warnings) as a terminating error under "Stop".
function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    try { & $Exe @Arguments } finally { $ErrorActionPreference = $old }
    if ($LASTEXITCODE -ne 0) { Fail "'$Exe $($Arguments -join ' ')' failed (exit code $LASTEXITCODE)." }
}

# Run a native command silently (stderr discarded), return its stdout lines.
# The caller inspects $LASTEXITCODE. Same stderr/"Stop" workaround as above.
function Invoke-Quiet {
    param([string]$Exe, [string[]]$Arguments = @())
    $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    try { & $Exe @Arguments 2>$null } finally { $ErrorActionPreference = $old }
}

# Return [version] of a Python interpreter, or $null when unusable.
function Get-PythonVersion {
    param([string]$Exe, [string[]]$PreArgs = @())
    try {
        $out = Invoke-Quiet $Exe (@($PreArgs) + @("-c", "import sys; print('%d.%d.%d' % sys.version_info[:3])"))
        if ($LASTEXITCODE -eq 0 -and $out) { return [version]($out | Select-Object -First 1).Trim() }
    } catch { }
    return $null
}

# Find a Python >= $MinPython. Returns @{ Exe; PreArgs; Version } or $null.
function Find-Python {
    $candidates = @(
        @{ Exe = "py";      PreArgs = @("-3.12") },
        @{ Exe = "py";      PreArgs = @("-3.11") },
        @{ Exe = "py";      PreArgs = @("-3") },
        @{ Exe = "python";  PreArgs = @() },
        @{ Exe = "python3"; PreArgs = @() }
    )
    foreach ($c in $candidates) {
        if (-not (Get-Command $c.Exe -ErrorAction SilentlyContinue)) { continue }
        $v = Get-PythonVersion -Exe $c.Exe -PreArgs $c.PreArgs
        if (-not $v) { continue }   # also skips the Microsoft Store "python" stub
        if ($v -ge $MinPython) { return @{ Exe = $c.Exe; PreArgs = $c.PreArgs; Version = $v } }
        Warn "Found $($c.Exe) $($c.PreArgs -join ' ') ($v) but Python $MinPython or later is required."
    }
    return $null
}

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path", "User")
}

function ConvertTo-PlainText([SecureString]$s) {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

# ---------------------------------------------------------------- 1. Python
Info "Step 1/5: checking Python $MinPython or later"
$py = Find-Python
if (-not $py) {
    Warn "No suitable Python found."
    $go = $Yes
    if (-not $go) { $go = (Read-Host "Install Python 3.11 now? [y/N]") -match '^[Yy]$' }
    if (-not $go) { Fail "Python $MinPython+ is required. Install with: winget install Python.Python.3.11" }

    $installed = $false
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Info "Installing Python 3.11 via winget"
        $ErrorActionPreference = "Continue"
        try { & winget install --id Python.Python.3.11 -e --accept-package-agreements --accept-source-agreements } finally { $ErrorActionPreference = "Stop" }
        $installed = ($LASTEXITCODE -eq 0)
        if (-not $installed) { Warn "winget could not install Python (exit code $LASTEXITCODE) - trying the python.org installer." }
    } else {
        Info "winget not available - using the python.org installer."
    }

    if (-not $installed) {
        # 3.11.9 is the last 3.11 release that ships Windows installers.
        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
        $installerUrl  = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-$arch.exe"
        $installerPath = Join-Path $env:TEMP "python-3.11.9-$arch.exe"
        Info "Downloading $installerUrl"
        $downloaded = $false
        try {
            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
            $downloaded = $true
        } catch {
            Warn "Invoke-WebRequest failed: $($_.Exception.Message)"
        }
        if (-not $downloaded -and (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
            Info "Retrying download with curl.exe"
            $ErrorActionPreference = "Continue"
            try { & curl.exe -L --fail -o $installerPath $installerUrl } finally { $ErrorActionPreference = "Stop" }
            $downloaded = ($LASTEXITCODE -eq 0)
        }
        if (-not $downloaded -and (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue)) {
            Info "Retrying download with BITS"
            try { Start-BitsTransfer -Source $installerUrl -Destination $installerPath; $downloaded = $true } catch { Warn "BITS failed: $($_.Exception.Message)" }
        }
        if (-not $downloaded) {
            Fail "Could not download the Python installer (a proxy or firewall may be blocking python.org). Download it manually from https://www.python.org/downloads/windows/ (tick 'Add python.exe to PATH') and re-run."
        }
        Info "Running the installer silently (per-user, adds Python to PATH)"
        $p = Start-Process -FilePath $installerPath -ArgumentList "/quiet", "InstallAllUsers=0", "PrependPath=1", "Include_pip=1", "Include_launcher=1" -Wait -PassThru
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        if ($p.ExitCode -ne 0) { Fail "The Python installer failed (exit code $($p.ExitCode))." }
    }
    Update-SessionPath
    $py = Find-Python
    if (-not $py) { Fail "Python was installed but is not yet visible. Open a NEW PowerShell window and re-run this script." }
}
Ok "Python $($py.Version) ($($py.Exe) $($py.PreArgs -join ' '))"

# ---------------------------------------------------------------- 2. venv + pip
Info "Step 2/5: checking venv module and pip"
Invoke-Quiet $py.Exe (@($py.PreArgs) + @("-c", "import venv, ensurepip")) | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "The Python 'venv' module is missing. Reinstall Python (include pip and the standard library) and re-run." }
Ok "venv module available"

$VenvDir = Join-Path $WorkspaceDir ".venv"
$VenvPy  = Join-Path $VenvDir "Scripts\python.exe"

if (Test-Path $VenvPy) {
    $vv = Get-PythonVersion -Exe $VenvPy
    if ($vv -and $vv -ge $MinPython) {
        Ok "Existing virtual environment found ($VenvDir, Python $vv)"
    } else {
        Fail "Existing virtual environment $VenvDir uses Python $(if ($vv) { $vv } else { 'unknown' }) (< $MinPython). Delete it (Remove-Item -Recurse -Force '$VenvDir') and re-run."
    }
} else {
    Info "Creating workspace and virtual environment in $VenvDir"
    New-Item -ItemType Directory -Force -Path $WorkspaceDir | Out-Null
    Invoke-Native $py.Exe (@($py.PreArgs) + @("-m", "venv", $VenvDir))
    Ok "Virtual environment created"
}

Invoke-Quiet $VenvPy @("-m", "pip", "--version") | Out-Null
if ($LASTEXITCODE -ne 0) {
    Info "pip missing in the virtual environment - bootstrapping with ensurepip"
    Invoke-Native $VenvPy @("-m", "ensurepip", "--upgrade")
}
Ok ("pip " + ((Invoke-Quiet $VenvPy @("-m", "pip", "--version") | Select-Object -First 1) -split ' ')[1])

# ---------------------------------------------------------------- 3. ADK package
function Get-InstalledAdkVersion {
    $line = Invoke-Quiet $VenvPy @("-m", "pip", "show", $Package) | Where-Object { $_ -match '^Version:' } | Select-Object -First 1
    if ($line) {
        # Strip pre-release/local suffixes (e.g. 2.16.0rc1) before parsing.
        $m = [regex]::Match($line, '(\d+(\.\d+){1,2})')
        if ($m.Success) { return [version]$m.Value }
    }
    return $null
}

Info "Step 3/5: checking ADK ($Package) version >= $MinAdk"
$adk = Get-InstalledAdkVersion
if ($adk -and $adk -ge $MinAdk) {
    Ok "ADK $adk already installed - no change needed"
} else {
    if ($adk) { Info "ADK $adk is older than $MinAdk - upgrading" } else { Info "ADK not installed - installing" }
    Invoke-Native $VenvPy @("-m", "pip", "install", "--upgrade", $Package)
    $adk = Get-InstalledAdkVersion
    if (-not $adk -or $adk -lt $MinAdk) { Fail "After install, ADK version is '$adk' (need >= $MinAdk)." }
    Ok "ADK $adk installed"
}

# ---------------------------------------------------------------- 4. CLI check
Info "Step 4/5: verifying the orchestrate CLI"
$Orch = Join-Path $VenvDir "Scripts\orchestrate.exe"
if (-not (Test-Path $Orch)) { Fail "orchestrate executable not found at $Orch" }
Invoke-Native $Orch @("--version")
Ok "orchestrate CLI runs"

# ---------------------------------------------------------------- 5. environment
if ($SkipEnv) {
    Info "Step 5/5: skipped (-SkipEnv)"
    Write-Host ""
    Info "ADK setup complete (pre-event mode). When the event begins:"
    Write-Host "  1. Log in to the wxO TechJam tenant and retrieve your credentials:"
    Write-Host "     - Click your user profile (top-right) → Settings"
    Write-Host "     - Select API details tab"
    Write-Host "     - Copy the Service instance URL and generate an API key"
    Write-Host "  2. Re-run this script WITHOUT -SkipEnv to configure the environment:"
    Write-Host "     .\labs\adk-setup\setup-adk.ps1 -Url <URL>"
    Write-Host ""
} else {
    Info "Step 5/5: configuring wxO environment '$EnvName'"

    $envList = (Invoke-Quiet $Orch @("env", "list")) -join "`n"
    if ($envList -match "(?<![\w-])$([regex]::Escape($EnvName))(?![\w-])") {
        Ok "Environment '$EnvName' is already registered - skipping 'env add'"
    } else {
        if (-not $Url) { $Url = Read-Host "wxO service instance URL (Settings > API details)" }
        if (-not $Url) { Fail "A service instance URL is required." }
        Invoke-Native $Orch @("env", "add", "-n", $EnvName, "-u", $Url, "--type", "mcsp")
        Ok "Environment '$EnvName' added"
    }

    if ($ApiKey) {
        $plainKey = ConvertTo-PlainText $ApiKey
    } elseif ($env:WXO_API_KEY) {
        $plainKey = $env:WXO_API_KEY
    } else {
        $plainKey = ConvertTo-PlainText (Read-Host "wxO API key (input hidden)" -AsSecureString)
    }
    if (-not $plainKey) { Fail "An API key is required." }
    Invoke-Native $Orch @("env", "activate", $EnvName, "-a", $plainKey)
    $plainKey = $null
    Ok "Environment '$EnvName' activated"

    Info "Verifying connectivity"
    Invoke-Quiet $Orch @("agents", "list") | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "'orchestrate agents list' failed - check the URL and API key." }
    Ok "Connected to wxO"
}

# ---------------------------------------------------------------- done
Write-Host ""
Ok "ADK setup complete (ADK $adk)."
Write-Host "  Activate the virtual environment in each new terminal with:"
Write-Host "    $VenvDir\Scripts\Activate.ps1"
Write-Host "  Tokens expire after 2 hours of inactivity; refresh with:"
Write-Host "    orchestrate env activate $EnvName"
