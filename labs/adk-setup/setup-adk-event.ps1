<#
.SYNOPSIS
    Install the watsonx Orchestrate ADK CLI and connect it to the wxO tenant (on event day).

.DESCRIPTION
    Automates "Appendix: ADK CLI Setup Guide" in
    lab-guides/Setup & Event Credentials.md (sections A.1 - A.5).

    Verifies Python and the ADK CLI (installing if needed), then registers and
    activates the wxO environment using credentials from labs/event.env.

    Every dependency is checked first (existence AND version); nothing is installed
    or changed if it is already in place and recent enough.

    Anything still missing (e-mail, API key, URL) is asked for once, up front,
    before the install steps start.

.PARAMETER Email
    Your event e-mail address. When supplied, the script looks up your SOR user ID and
    password from the Jam User Management app and writes them to sorUsername / sorPassword
    in labs/event.env before doing anything else. Without -Email, non-blank sorUsername AND
    sorPassword in labs/event.env are used as they are (a message says so); otherwise the
    e-mail address is asked for. An address that does not look valid has to be confirmed or
    replaced. An address that is not registered in SOR stops the script. The script also stops
    when labs/event.env does not exist (start it from the right workspace).

.PARAMETER Location
    Jam location used for the credential lookup. Default: APAC

.PARAMETER WorkspaceDir
    Lab workspace directory holding the .venv. Default: .\wxo-labs

.PARAMETER EnvName
    ADK environment name. Default: trinity-lab

.PARAMETER SorUrl
    SOR base URL. Read from labs/event.env (sorURL) when not supplied, then from the SOR_URL
    environment variable, then prompted if still missing. A value that differs from the one
    in labs/event.env is saved back to sorURL.

.PARAMETER Url
    wxO service instance URL. Read from labs/event.env (wxoServiceInstanceURL) when not
    supplied, then from the WXO_URL environment variable, then prompted if still missing.

.PARAMETER ApiKey
    wxO API key as a plain string. Read from labs/event.env (wxoAPIKey) when not supplied,
    then from the WXO_API_KEY environment variable, then prompted (hidden) if still missing.
    Saved to wxoAPIKey in labs/event.env (only when it differs) so -Activate can reuse it.

.PARAMETER Activate
    Only refresh the wxO token (e.g. after it expired): re-activates the registered environment
    with the wxoAPIKey from labs/event.env (asks for it only if missing) and exits. Skips the
    Python/ADK checks and every other prompt.

.PARAMETER Reset
    Only removes the registered wxO environment and blanks wxoAPIKey, sorUsername and sorPassword in
    labs/event.env, then exits. It does not install anything, ask questions or create a new
    environment: run the script again without -Reset to register it afresh. sorURL and
    wxoServiceInstanceURL are left untouched.

.PARAMETER Yes
    Do not ask before installing Python.

.EXAMPLE
    .\labs\adk-setup\setup-adk-event.ps1

.EXAMPLE
    .\labs\adk-setup\setup-adk-event.ps1 -Email jane.doe@ibm.com -Location Americas

.EXAMPLE
    .\labs\adk-setup\setup-adk-event.ps1 -Url https://api.example.com/instances/abc -EnvName trinity-lab

.NOTES
    If script execution is blocked, run once in this session:
      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>
[CmdletBinding()]
param(
    [Alias("e")]
    [string]$Email,
    [Alias("l")]
    [string]$Location     = "Americas",
    [string]$WorkspaceDir = ".\wxo-labs",
    [string]$EnvName      = "trinity-lab",
    [Alias("s")]
    [string]$SorUrl,
    [Alias("u")]
    [string]$Url,
    [Alias("k")]
    [string]$ApiKey,
    [Alias("a")]
    [switch]$Activate,
    [Alias("r")]
    [switch]$Reset,
    [switch]$Yes
)

$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 may default to TLS 1.0/1.1, which python.org rejects.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

# ---------------------------------------------------------------- event.env
# Read labs/event.env (one directory up from this script) and populate $SorUrl, $Url
# and $ApiKey from it when they were not supplied on the command line.
# Precedence: CLI param > event.env > SOR_URL / WXO_URL / WXO_API_KEY env vars > interactive prompt.
$_EventEnvPath = Join-Path $PSScriptRoot "..\event.env"
$_ApiKeyFromCli = $PSBoundParameters.ContainsKey('ApiKey')
$_SorUrlFromFile = ""
$_UrlFromFile = ""
$_ApiKeyFromFile = ""
$_HaveSorUser = $false
$DefaultKeyGenUrl = "https://github.com/IBM/ba-wxo-tech-jam/blob/main/lab-guides/Generate%20Your%20wxO%20API%20Key.md"
$_KeyGenUrl = ""   # wxoKeyGenUrl from labs/event.env; $DefaultKeyGenUrl when missing
$_HaveSorPass = $false
if (Test-Path $_EventEnvPath) {
    foreach ($line in (Get-Content $_EventEnvPath -Encoding UTF8)) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $k, $v = $line -split '=', 2
        $k = $k.Trim(); $v = "$v".Trim()
        if (-not $v) { continue }
        if ($k -eq 'wxoKeyGenUrl') { $_KeyGenUrl = $v }
        if ($k -eq 'sorUsername') { $_HaveSorUser = $true }
        if ($k -eq 'sorPassword') { $_HaveSorPass = $true }
        if ($k -eq 'sorURL'                -and -not $SorUrl) { $SorUrl = $v; $_SorUrlFromFile = $v }
        if ($k -eq 'wxoServiceInstanceURL' -and -not $Url)   { $Url    = $v; $_UrlFromFile = $v }
        if ($k -eq 'wxoAPIKey'             -and -not $ApiKey) {
            $ApiKey = $v
            $_ApiKeyFromFile = $v
        }
    }
}

if ($Activate -and $Reset) { Write-Host "[FAIL] -Activate and -Reset cannot be combined." -ForegroundColor Red; exit 1 }

# Environment-variable fallback: only for values neither the parameters nor event.env provided.
if (-not $SorUrl) { $SorUrl = $env:SOR_URL }
if (-not $Url)    { $Url    = $env:WXO_URL }

$MinPython = [version]"3.12"
$MinAdk    = [version]"2.15"
$Package   = "ibm-watsonx-orchestrate"

# ---------------------------------------------------------------- helpers
function Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
# Highlight: green, for the messages the user must not miss (the console has no bold)
function Hilite($m) { Write-Host "[INFO] $m" -ForegroundColor Green }
function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; Show-EnvChanges; exit 1 }

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
        @{ Exe = "py";      PreArgs = @("-3.13") },
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

# event.env entries changed by this run (secrets masked); listed by Show-EnvChanges at the end of the run,
# on failures and before the -Activate / -Reset exits.
$script:_EnvChanges = New-Object System.Collections.Generic.List[string]
function Show-EnvChanges {
    if ($script:_EnvChanges.Count -eq 0) { return }
    $path = if ($_EventEnvPath) { $_EventEnvPath } else { "event.env" }
    Write-Host ""
    Info "$path has been updated with the following changes:"
    foreach ($entry in $script:_EnvChanges) { Write-Host "    - $entry" }
    $script:_EnvChanges.Clear()
}

# Set key=value in an env file (replace the existing line, or append), preserving everything else.
# A real change (old value differs from the new one) is remembered for Show-EnvChanges.
function Set-EnvValue([string]$Path, [string]$Key, [string]$Value) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $text = if (Test-Path $Path) { [IO.File]::ReadAllText($Path, $utf8) } else { "" }
    $pattern = "(?m)^[ \t]*$([regex]::Escape($Key))[ \t]*=[^\r\n]*"
    $old = ""
    $found = [regex]::Match($text, $pattern)
    if ($found.Success) { $old = $found.Value.Substring($found.Value.IndexOf("=") + 1).Trim() }
    if ($old -ne $Value) {
        $shown = if (-not $Value) { "$Key (cleared)" }
                 elseif ($Key -eq "sorPassword" -or $Key -eq "wxoAPIKey") { "$Key=********" }
                 else { "$Key=$Value" }
        $script:_EnvChanges.Add($shown)
    }
    if ($found.Success) {
        $text = [regex]::Replace($text, $pattern, { param($m) "$Key=$Value" })
    } else {
        if ($text -and -not $text.EndsWith("`n")) { $text += "`r`n" }
        $text += "$Key=$Value`r`n"
    }
    [IO.File]::WriteAllText($Path, $text, $utf8)
}

# True when the address looks like name@domain.tld
function Test-EmailAddress([string]$Address) {
    return ($Address -match '^[A-Za-z0-9._%+\x27-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$')
}

# Make sure $Email looks valid. If it does not, ask the user to confirm it is the right address (accept it
# as is) or to enter a new one, until the address is valid or confirmed.
function Confirm-EmailAddress {
    while (-not (Test-EmailAddress $script:Email)) {
        Warn "'$($script:Email)' does not look like a valid e-mail address."
        if ((Read-Host "Is it the right e-mail address? [y/N]") -match '^[Yy]$') { return }
        $script:Email = Read-Host "Event e-mail address (used to look up sorUsername/sorPassword)"
        if (-not $script:Email) { Fail "An e-mail address is required. Pass -Email or enter it when asked." }
    }
}

# Tell the user how to generate the wxO API key (only when no key is known yet, because the key is asked for right after).
function Show-KeyGenHint([string]$SorUser) {
    if ($ApiKey -or $env:WXO_API_KEY) { return }
    $link = if ($_KeyGenUrl) { $_KeyGenUrl } else { $DefaultKeyGenUrl }
    Write-Host ""
    Hilite "Please write down your SOR user name: $SorUser"
    Hilite "Follow this link to generate your wxO API key: $link"
    Hilite "Use your SOR user name ($SorUser) as the API key name."
    Hilite "Once the API key is generated, enter it below to continue the ADK setup."
}

# POST the e-mail to the Jam User Management app and store the returned user ID / password
# in event.env (sorUsername / sorPassword).
function Get-SorCredentials {
    $credUrl = "https://jam-usermanagement-jam-usermanagement.swat-dev-roks-vpc-02-464887bc828751e1b00625ca9211fbca-0000.eu-de.containers.appdomain.cloud/UserManagement/RetrieveUserCredential.jsp"
    Info "Retrieving SOR credentials for $Email ($Location)"
    try {
        $resp = Invoke-WebRequest -Uri $credUrl -Method Post -UseBasicParsing -TimeoutSec 30 -Body @{
            EmailAddressTextbox = $Email
            jamLocationCombox   = $Location
            UserType            = "CP4BA"
        }
    } catch {
        Fail "Could not retrieve credentials from the Jam User Management app (check network/VPN, the e-mail address and -Location): $($_.Exception.Message)"
    }
    $html = [string]$resp.Content
    if ($html -match '(?i)registration list') {
        Fail "Could not find the e-mail address $Email in SOR. Please contact the tech-jam team to register the e-mail address and try again."
    }
    $u = [regex]::Match($html, '<b>User ID:\s*</b>\s*([^<\s]+)')
    $p = [regex]::Match($html, '<b>Password:\s*</b>\s*([^<\s]+)')
    if (-not $u.Success -or -not $p.Success) {
        Fail "No user ID / password found in the response for $Email. Check the e-mail address and -Location (Americas / APAC)."
    }
    Set-EnvValue $_EventEnvPath "sorUsername" $u.Groups[1].Value
    Set-EnvValue $_EventEnvPath "sorPassword" $p.Groups[1].Value
    Ok "Saved sorUsername=$($u.Groups[1].Value) and sorPassword=******** to $_EventEnvPath"
    Show-KeyGenHint $u.Groups[1].Value
}

# Keep the API key in event.env (only when it differs from what is stored) so that -Activate can
# refresh the token later without asking for it again.
function Save-ApiKey([string]$PlainKey) {
    if (-not $PlainKey -or $PlainKey -eq $script:_ApiKeyFromFile) { return }
    Set-EnvValue $_EventEnvPath "wxoAPIKey" $PlainKey
    $script:_ApiKeyFromFile = $PlainKey
    Ok "Saved wxoAPIKey to $_EventEnvPath"
}

# Decide where the wxO API key comes from and say so: -ApiKey on the command line, else a non-blank
# wxoAPIKey in event.env, else the WXO_API_KEY environment variable, else ask (hidden).
function Resolve-ApiKey {
    if ($script:ApiKey) {
        if ($script:_ApiKeyFromCli)      { Info "Will use the wxO API key from the command line" }
        elseif ($script:_ApiKeyFromFile) { Info "Will use the wxO API key (wxoAPIKey) from $_EventEnvPath" }
    } elseif ($env:WXO_API_KEY) {
        $script:ApiKey = $env:WXO_API_KEY
        Info "Will use the wxO API key from the WXO_API_KEY environment variable"
    } else {
        $script:ApiKey = ConvertTo-PlainText (Read-Host "wxO API key (wxoAPIKey; input hidden)" -AsSecureString)
    }
}

# True when the ADK environment $EnvName is registered ($Orch must be set).
function Test-EnvRegistered {
    $list = (Invoke-Quiet $Orch @("env", "list")) -join "`n"
    return ($list -match "(?<![\w-])$([regex]::Escape($EnvName))(?![\w-])")
}

# ---------------------------------------------------------------- event.env must exist
if (-not (Test-Path $_EventEnvPath)) {
    Fail "labs\event.env was not found (looked for $_EventEnvPath). The script must be started from the right workspace: run it from the Tech Jam repository, e.g. .\labs\adk-setup\setup-adk-event.ps1."
}

# ---------------------------------------------------------------- -Activate (token refresh only)
# Tokens expire after 2 hours of inactivity. Re-activating the already registered environment only
# needs the API key, so skip the Python/ADK checks and every other prompt.
if ($Activate) {
    Info "Refreshing the wxO token for environment '$EnvName'"
    $Orch = Join-Path (Join-Path $WorkspaceDir ".venv") "Scripts\orchestrate.exe"
    if (-not (Test-Path $Orch)) {
        $cmd = Get-Command orchestrate -ErrorAction SilentlyContinue
        if (-not $cmd) { Fail "orchestrate CLI not found in $WorkspaceDir\.venv or on PATH. Run this script without -Activate first to install the ADK." }
        $Orch = $cmd.Source
    }
    if (-not (Test-EnvRegistered)) { Fail "Environment '$EnvName' is not registered. Run this script without -Activate first." }
    Resolve-ApiKey
    $plainKey = if ($ApiKey) { $ApiKey } else { "" }
    if (-not $plainKey) { Fail "An API key is required. Pass -ApiKey or enter it when asked." }
    Invoke-Native $Orch @("env", "activate", $EnvName, "-a", $plainKey)
    Ok "Environment '$EnvName' activated"
    Save-ApiKey $plainKey
    $plainKey = $null
    Invoke-Quiet $Orch @("agents", "list") | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "'orchestrate agents list' failed - check the API key and wxoServiceInstanceURL." }
    Ok "Connected to wxO"
    Show-EnvChanges
    exit 0
}

# ---------------------------------------------------------------- -Reset (remove only)
# Removes the registered environment and blanks the saved API key, then stops. Nothing is installed,
# asked or re-created; run the script again without -Reset to register the environment afresh.
if ($Reset) {
    Info "Resetting: removing environment '$EnvName'"
    $Orch = Join-Path (Join-Path $WorkspaceDir ".venv") "Scripts\orchestrate.exe"
    if (-not (Test-Path $Orch)) {
        $cmd = Get-Command orchestrate -ErrorAction SilentlyContinue
        $Orch = if ($cmd) { $cmd.Source } else { $null }
    }
    if (-not $Orch) {
        Ok "orchestrate CLI not found - no environment to remove"
    } elseif (Test-EnvRegistered) {
        Invoke-Native $Orch @("env", "remove", "-n", $EnvName)
        Ok "Environment '$EnvName' removed"
    } else {
        Ok "Environment '$EnvName' is not registered - nothing to remove"
    }
    if ($_ApiKeyFromFile) {
        Set-EnvValue $_EventEnvPath "wxoAPIKey" ""
        Ok "Cleared wxoAPIKey in $_EventEnvPath"
    }
    if ($_HaveSorUser) {
        Set-EnvValue $_EventEnvPath "sorUsername" ""
        Ok "Cleared sorUsername in $_EventEnvPath"
    }
    if ($_HaveSorPass) {
        Set-EnvValue $_EventEnvPath "sorPassword" ""
        Ok "Cleared sorPassword in $_EventEnvPath"
    }
    Write-Host "  Run .\setup-adk-event.ps1 again (without -Reset) to register the environment."
    Show-EnvChanges
    exit 0
}

# ---------------------------------------------------------------- collect inputs
# Ask for everything that is still missing up front, so the rest of the script runs unattended.
# Skipped for values already supplied via parameters, labs/event.env or environment variables.
# The e-mail is only needed to look up sorUsername/sorPassword: with -Email the credentials are fetched again;
# without it they are used from event.env when both are non-blank, otherwise the e-mail is asked for.
# The address is checked and looked up right away, so an unregistered address stops the script before anything else is asked.
if ($Email) {
    # -Email given: sorUsername/sorPassword are fetched and overwrite the file values
} elseif ($_HaveSorUser -and $_HaveSorPass) {
    Info "Will use sorUsername and sorPassword from $_EventEnvPath"
} else {
    Info "sorUsername and sorPassword are not set in $_EventEnvPath - they will be looked up from your e-mail address."
    $Email = Read-Host "Event e-mail address (used to look up sorUsername/sorPassword)"
    if (-not $Email) { Fail "An e-mail address is required: sorUsername/sorPassword are not set in $_EventEnvPath. Pass -Email or enter it when asked." }
}
if ($Email) {
    Confirm-EmailAddress
    Get-SorCredentials
}
if (-not $SorUrl) { $SorUrl = Read-Host "SOR base URL (sorURL; Enter to skip)" }
Resolve-ApiKey
if (-not $ApiKey) { Fail "A wxO API key is required: wxoAPIKey is not set in $_EventEnvPath. Pass -ApiKey or enter it when asked." }
if (-not $Url) {
    $Url = Read-Host "wxO service instance URL (wxoServiceInstanceURL; Enter to skip if the environment is already registered)"
}

if ($SorUrl -and $SorUrl -ne $_SorUrlFromFile) {
    Set-EnvValue $_EventEnvPath "sorURL" $SorUrl
    Ok "Saved sorURL=$SorUrl to $_EventEnvPath"
}
if ($Url -and $Url -ne $_UrlFromFile) {
    Set-EnvValue $_EventEnvPath "wxoServiceInstanceURL" $Url
    Ok "Saved wxoServiceInstanceURL=$Url to $_EventEnvPath"
}

# ---------------------------------------------------------------- 1. Python
Info "Step 1/5: checking Python $MinPython or later"
$py = Find-Python
if (-not $py) {
    Warn "No suitable Python found."
    $go = $Yes
    if (-not $go) { $go = (Read-Host "Install Python 3.12 now? [y/N]") -match '^[Yy]$' }
    if (-not $go) { Fail "Python $MinPython+ is required. Install with: winget install Python.Python.3.12" }

    $installed = $false
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Info "Installing Python 3.12 via winget"
        $ErrorActionPreference = "Continue"
        try { & winget install --id Python.Python.3.12 -e --accept-package-agreements --accept-source-agreements } finally { $ErrorActionPreference = "Stop" }
        $installed = ($LASTEXITCODE -eq 0)
        if (-not $installed) { Warn "winget could not install Python (exit code $LASTEXITCODE) - trying the python.org installer." }
    } else {
        Info "winget not available - using the python.org installer."
    }

    if (-not $installed) {
        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
        $installerUrl  = "https://www.python.org/ftp/python/3.12.10/python-3.12.10-$arch.exe"
        $installerPath = Join-Path $env:TEMP "python-3.12.10-$arch.exe"
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
            Fail "Could not download the Python installer (a proxy or firewall may be blocking python.org). Download it manually from https://www.python.org/downloads/windows/ and re-run (tick 'Add python.exe to PATH')."
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
    Info "Step 5/5: configuring wxO environment '$EnvName'"

    if (Test-EnvRegistered) {
        Ok "Environment '$EnvName' is already registered - skipping 'env add'"
    } else {
        if (-not $Url) { $Url = Read-Host "wxO service instance URL (wxoServiceInstanceURL in labs/event.env)" }
        if (-not $Url) { Fail "A service instance URL is required. Set wxoServiceInstanceURL in labs/event.env or pass -Url." }
        Invoke-Native $Orch @("env", "add", "-n", $EnvName, "-u", $Url, "--type", "mcsp")
        Ok "Environment '$EnvName' added"
    }

    if ($ApiKey) {
        $plainKey = $ApiKey
    } elseif ($env:WXO_API_KEY) {
        $plainKey = $env:WXO_API_KEY
    } else {
        $plainKey = ConvertTo-PlainText (Read-Host "wxO API key (wxoAPIKey in labs/event.env; input hidden)" -AsSecureString)
    }
    if (-not $plainKey) { Fail "An API key is required. Set wxoAPIKey in labs/event.env or pass -ApiKey." }
    Invoke-Native $Orch @("env", "activate", $EnvName, "-a", $plainKey)
    Ok "Environment '$EnvName' activated"
    Save-ApiKey $plainKey   # only after a successful activation, so a mistyped key is never stored
    $plainKey = $null

    Info "Verifying connectivity"
    Invoke-Quiet $Orch @("agents", "list") | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "'orchestrate agents list' failed - check wxoServiceInstanceURL and wxoAPIKey in labs/event.env." }
    Ok "Connected to wxO"

# ---------------------------------------------------------------- done
Write-Host ""
Ok "ADK setup complete (ADK $adk)."
Write-Host "  Activate the virtual environment in each new terminal with:"
Write-Host "    $VenvDir\Scripts\Activate.ps1"
Write-Host "  Tokens expire after 2 hours of inactivity; refresh with:"
Write-Host "    .\labs\adk-setup\setup-adk-event.ps1 -Activate"
Show-EnvChanges
