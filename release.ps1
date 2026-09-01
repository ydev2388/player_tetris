#requires -Version 7.0

param(
    [string]$Version = "",
    [string]$GodotPath = "",
    [switch]$AllowUntagged,
    [switch]$SkipBrowserSmoke
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = $PSScriptRoot
$Git = (Get-Command git -ErrorAction Stop).Source
$CanonicalVersion = (Get-Content -LiteralPath (Join-Path $ProjectRoot "VERSION") -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = $CanonicalVersion
}
if ($Version -ne $CanonicalVersion) {
    throw "Requested version '$Version' does not match VERSION '$CanonicalVersion'."
}

function Invoke-Git {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $Output = @(& $Git -C $ProjectRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed:`n$($Output -join [Environment]::NewLine)"
    }
    return ($Output -join "`n").Trim()
}

function Get-RelativeEvidencePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [IO.Path]::GetRelativePath($ReleaseDirectory, $Path).Replace("\", "/")
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Invoke-CdpCommand {
    param(
        [Parameter(Mandatory = $true)][Net.WebSockets.ClientWebSocket]$Socket,
        [Parameter(Mandatory = $true)][ref]$CommandId,
        [Parameter(Mandatory = $true)][string]$Method,
        [object]$Parameters = $null,
        [Collections.Generic.List[object]]$Events = $null
    )
    $CommandId.Value++
    $Payload = [ordered]@{ id = $CommandId.Value; method = $Method }
    if ($null -ne $Parameters) {
        $Payload["params"] = $Parameters
    }
    $Bytes = [Text.Encoding]::UTF8.GetBytes(($Payload | ConvertTo-Json -Depth 8 -Compress))
    $Socket.SendAsync(
        [ArraySegment[byte]]::new($Bytes),
        [Net.WebSockets.WebSocketMessageType]::Text,
        $true,
        [Threading.CancellationToken]::None
    ).GetAwaiter().GetResult() | Out-Null

    while ($true) {
        $Buffer = [byte[]]::new(65536)
        $MessageStream = [IO.MemoryStream]::new()
        do {
            $ReceiveResult = $Socket.ReceiveAsync(
                [ArraySegment[byte]]::new($Buffer),
                [Threading.CancellationToken]::None
            ).GetAwaiter().GetResult()
            if ($ReceiveResult.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) {
                throw "Browser DevTools connection closed during '$Method'."
            }
            $MessageStream.Write($Buffer, 0, $ReceiveResult.Count)
        } while (-not $ReceiveResult.EndOfMessage)
        $MessageText = [Text.Encoding]::UTF8.GetString($MessageStream.ToArray())
        $Message = $MessageText | ConvertFrom-Json
        $IdProperty = $Message.PSObject.Properties["id"]
        if ($null -ne $IdProperty -and [int]$IdProperty.Value -eq $CommandId.Value) {
            $ErrorProperty = $Message.PSObject.Properties["error"]
            if ($null -ne $ErrorProperty) {
                throw "Browser DevTools command '$Method' failed: $($ErrorProperty.Value.message)"
            }
            return $Message.PSObject.Properties["result"].Value
        }
        $MethodProperty = $Message.PSObject.Properties["method"]
        if ($null -ne $Events -and $null -ne $MethodProperty -and -not [string]::IsNullOrWhiteSpace([string]$MethodProperty.Value)) {
            $Events.Add($Message)
        }
    }
}

function Get-PngVisualMetrics {
    param([Parameter(Mandatory = $true)][string]$Path)
    Add-Type -AssemblyName System.Drawing.Common
    $Bitmap = [Drawing.Bitmap]::new($Path)
    try {
        $Colors = [Collections.Generic.HashSet[int]]::new()
        $LuminanceTotal = 0.0
        $LightPixels = 0
        $SampleCount = 0
        for ($Y = 0; $Y -lt $Bitmap.Height; $Y += 10) {
            for ($X = 0; $X -lt $Bitmap.Width; $X += 10) {
                $Color = $Bitmap.GetPixel($X, $Y)
                [void]$Colors.Add($Color.ToArgb())
                $Luminance = 0.2126 * $Color.R + 0.7152 * $Color.G + 0.0722 * $Color.B
                $LuminanceTotal += $Luminance
                if ($Luminance -gt 200.0) { $LightPixels++ }
                $SampleCount++
            }
        }
        return [ordered]@{
            sampled_unique_colors = $Colors.Count
            average_luminance = [Math]::Round($LuminanceTotal / $SampleCount, 2)
            light_pixel_ratio = [Math]::Round($LightPixels / $SampleCount, 4)
        }
    }
    finally {
        $Bitmap.Dispose()
    }
}

function Assert-NoEngineErrors {
    param(
        [Parameter(Mandatory = $true)][string]$StepName,
        [Parameter(Mandatory = $true)][string[]]$LogPaths
    )
    $DisallowedPattern = "(?im)^\s*(SCRIPT ERROR|ERROR:|Parse Error|Compile Error)|ObjectDB instances were leaked|Resource still in use|resources still in use"
    $Matches = @()
    foreach ($LogPath in $LogPaths) {
        if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
            $Text = Get-Content -LiteralPath $LogPath -Raw
            $Matches += [regex]::Matches($Text, $DisallowedPattern)
        }
    }
    if ($Matches.Count -ne 0) {
        throw "Step '$StepName' contains $($Matches.Count) disallowed engine error marker(s)."
    }
}

$Steps = [ordered]@{}
function Invoke-ProcessStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$EngineLogPath = "",
        [int]$TimeoutSeconds = 300
    )

    $ProcessLogPath = Join-Path $LogsDirectory "$Name.process.log"
    $StartedAt = [DateTimeOffset]::UtcNow
    $StartInfo = [Diagnostics.ProcessStartInfo]::new()
    $StartInfo.FileName = $FilePath
    $StartInfo.UseShellExecute = $false
    $StartInfo.CreateNoWindow = $true
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    foreach ($Argument in $Arguments) {
        $StartInfo.ArgumentList.Add($Argument)
    }

    $Process = [Diagnostics.Process]::new()
    $Process.StartInfo = $StartInfo
    if (-not $Process.Start()) {
        throw "Could not start release step '$Name'."
    }
    $StdoutTask = $Process.StandardOutput.ReadToEndAsync()
    $StderrTask = $Process.StandardError.ReadToEndAsync()
    if (-not $Process.WaitForExit($TimeoutSeconds * 1000)) {
        $Process.Kill($true)
        $Process.WaitForExit()
        throw "Release step '$Name' timed out after $TimeoutSeconds seconds."
    }
    $Stdout = $StdoutTask.GetAwaiter().GetResult()
    $Stderr = $StderrTask.GetAwaiter().GetResult()
    $Combined = $Stdout
    if (-not [string]::IsNullOrWhiteSpace($Stderr)) {
        $Combined += "`n[stderr]`n$Stderr"
    }
    [IO.File]::WriteAllText($ProcessLogPath, $Combined, [Text.UTF8Encoding]::new($false))

    $ExitCode = $Process.ExitCode
    $FinishedAt = [DateTimeOffset]::UtcNow
    $StepEvidence = [ordered]@{
        exit_code = $ExitCode
        started_at_utc = $StartedAt.ToString("o")
        finished_at_utc = $FinishedAt.ToString("o")
        process_log = Get-RelativeEvidencePath $ProcessLogPath
        engine_log = $null
        assertions = $null
        assertion_failures = $null
        expected_result_marker = $null
        result_marker_found = $null
        unexpected_engine_errors = $null
    }
    if (-not [string]::IsNullOrWhiteSpace($EngineLogPath)) {
        if (-not (Test-Path -LiteralPath $EngineLogPath -PathType Leaf)) {
            throw "Release step '$Name' did not create its engine log: $EngineLogPath"
        }
        $StepEvidence.engine_log = Get-RelativeEvidencePath $EngineLogPath
    }
    $Steps[$Name] = $StepEvidence

    if ($ExitCode -ne 0) {
        throw "Release step '$Name' failed with exit code $ExitCode. See $ProcessLogPath"
    }
    $LogsToCheck = @($ProcessLogPath)
    if (-not [string]::IsNullOrWhiteSpace($EngineLogPath)) {
        $LogsToCheck += $EngineLogPath
    }
    Assert-NoEngineErrors -StepName $Name -LogPaths $LogsToCheck
    $StepEvidence.unexpected_engine_errors = 0
    Write-Host "[PASS] $Name"
    return $ProcessLogPath
}

function Assert-TestResult {
    param(
        [Parameter(Mandatory = $true)][string]$StepName,
        [Parameter(Mandatory = $true)][string]$ProcessLogPath,
        [Parameter(Mandatory = $true)][string]$MarkerPattern,
        [int]$ExpectedAssertions = -1
    )
    $Text = Get-Content -LiteralPath $ProcessLogPath -Raw
    $ResultMatches = [regex]::Matches($Text, $MarkerPattern)
    if ($ResultMatches.Count -ne 1) {
        throw "Step '$StepName' must emit exactly one result marker; found $($ResultMatches.Count)."
    }
    $StepEvidence = $Steps[$StepName]
    $StepEvidence.expected_result_marker = $MarkerPattern
    $StepEvidence.result_marker_found = $true
    $StepEvidence.assertion_failures = 0
    if ($ExpectedAssertions -ge 0) {
        $ActualAssertions = [int]$ResultMatches[0].Groups[1].Value
        if ($ActualAssertions -ne $ExpectedAssertions) {
            throw "Step '$StepName' ran $ActualAssertions assertions; expected exactly $ExpectedAssertions."
        }
        $StepEvidence.assertions = $ActualAssertions
    }
}

$ProjectText = Get-Content -LiteralPath (Join-Path $ProjectRoot "project.godot") -Raw
$ProjectVersionMatch = [regex]::Match($ProjectText, '(?m)^config/version="([^"]+)"$')
if (-not $ProjectVersionMatch.Success -or $ProjectVersionMatch.Groups[1].Value -ne $Version) {
    throw "project.godot config/version must equal VERSION ($Version)."
}

$Commit = Invoke-Git @("rev-parse", "HEAD")
$ShortCommit = Invoke-Git @("rev-parse", "--short=12", "HEAD")
$Dirty = Invoke-Git @("status", "--porcelain", "--untracked-files=all")
if (-not [string]::IsNullOrWhiteSpace($Dirty)) {
    throw "Release source is not clean:`n$Dirty"
}
$ExpectedTag = "v$Version"
if (-not $AllowUntagged) {
    $TagType = Invoke-Git @("cat-file", "-t", "refs/tags/$ExpectedTag")
    if ($TagType -ne "tag") {
        throw "$ExpectedTag must be an annotated tag; actual ref type is '$TagType'."
    }
    $TagCommit = Invoke-Git @("rev-list", "-n", "1", $ExpectedTag)
    if ($TagCommit -ne $Commit) {
        throw "$ExpectedTag points to $TagCommit, not release commit $Commit."
    }
    $ExactTags = @((Invoke-Git @("tag", "--points-at", "HEAD")) -split "`n")
    if ($ExactTags -notcontains $ExpectedTag) {
        throw "HEAD is not exactly tagged $ExpectedTag."
    }
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $WorkspaceRoot = Split-Path -Parent $ProjectRoot
    $GodotPath = Join-Path $WorkspaceRoot ".tools\godot\Godot_v4.7.1-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot 4.7.1 console executable was not found: $GodotPath"
}
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$GodotVersionOutput = @(& $GodotPath --version 2>&1)
$GodotVersionExitCode = $LASTEXITCODE
$GodotVersion = ($GodotVersionOutput | Select-Object -First 1).ToString().Trim()
if ($GodotVersionExitCode -ne 0 -or $GodotVersion -notmatch '^4\.7\.1\.stable\.official\.[0-9A-Za-z]+$') {
    throw "Expected Godot 4.7.1 stable official; got '$GodotVersion'."
}

$BuildRoot = Join-Path $ProjectRoot "build\releases"
$ReleaseId = "$Version-$ShortCommit"
$ReleaseDirectory = Join-Path $BuildRoot $ReleaseId
$ResolvedBuildRoot = [IO.Path]::GetFullPath($BuildRoot)
$ResolvedReleaseDirectory = [IO.Path]::GetFullPath($ReleaseDirectory)
if (-not $ResolvedReleaseDirectory.StartsWith($ResolvedBuildRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe release directory: $ResolvedReleaseDirectory"
}
if (Test-Path -LiteralPath $ResolvedReleaseDirectory) {
    Remove-Item -LiteralPath $ResolvedReleaseDirectory -Recurse -Force
}
$ReleaseDirectory = $ResolvedReleaseDirectory
$ArtifactDirectory = Join-Path $ReleaseDirectory "artifact"
$LogsDirectory = Join-Path $ReleaseDirectory "logs"
$RuntimeDirectory = Join-Path $ReleaseDirectory "runtime"
$WebDirectory = Join-Path $ReleaseDirectory "web"
New-Item -ItemType Directory -Force -Path $ArtifactDirectory, $LogsDirectory, $RuntimeDirectory, $WebDirectory | Out-Null
$BuildStartedAt = [DateTimeOffset]::UtcNow

function Invoke-GodotStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$GodotArguments
    )
    $EngineLog = Join-Path $LogsDirectory "$Name.engine.log"
    $Arguments = @("--headless", "--log-file", $EngineLog, "--path", $ProjectRoot) + $GodotArguments
    return Invoke-ProcessStep -Name $Name -FilePath $GodotPath -Arguments $Arguments -EngineLogPath $EngineLog
}

$ImportLog = Invoke-GodotStep -Name "import" -GodotArguments @("--import")

$MainGameLog = Invoke-GodotStep -Name "main_game_test" -GodotArguments @("--script", "res://tests/main_game_test.gd")
Assert-TestResult -StepName "main_game_test" -ProcessLogPath $MainGameLog -MarkerPattern 'TEST_RESULT suite=main_game checks=(\d+) failures=0' -ExpectedAssertions 230

$MainUiLog = Invoke-GodotStep -Name "main_ui_test" -GodotArguments @("--script", "res://start_screen/tests/main_ui_test.gd")
Assert-TestResult -StepName "main_ui_test" -ProcessLogPath $MainUiLog -MarkerPattern 'TEST_RESULT suite=main_ui checks=(\d+) failures=0' -ExpectedAssertions 115

$RuntimeTests = [ordered]@{
    hang_runtime = @("res://tests/hang_runtime_integration_test.gd", "HANG_RUNTIME_RESULT")
    corner_hang_runtime = @("res://tests/corner_hang_runtime_integration_test.gd", "CORNER_HANG_RUNTIME_RESULT")
    fall_runtime = @("res://tests/fall_runtime_integration_test.gd", "FALL_RUNTIME_RESULT")
    boxer_special_runtime = @("res://tests/boxer_special_runtime_integration_test.gd", "BOXER_SPECIAL_RUNTIME_RESULT")
    cleaner_special_runtime = @("res://tests/cleaner_special_runtime_integration_test.gd", "CLEANER_SPECIAL_RUNTIME_RESULT")
    firefighter_special_runtime = @("res://tests/firefighter_special_runtime_integration_test.gd", "FIREFIGHTER_SPECIAL_RUNTIME_RESULT")
    chef_meat_runtime = @("res://tests/chef_meat_runtime_integration_test.gd", "CHEF_MEAT_RUNTIME_RESULT")
    ninja_special_runtime = @("res://tests/ninja_special_runtime_integration_test.gd", "NINJA_SPECIAL_RUNTIME_RESULT")
}
foreach ($TestName in $RuntimeTests.Keys) {
    $TestSpec = $RuntimeTests[$TestName]
    $TestLog = Invoke-GodotStep -Name $TestName -GodotArguments @("--script", $TestSpec[0])
    Assert-TestResult -StepName $TestName -ProcessLogPath $TestLog -MarkerPattern ([regex]::Escape($TestSpec[1]))
}

$ExportLog = Invoke-GodotStep -Name "web_export" -GodotArguments @("--export-release", "Web", (Join-Path $WebDirectory "index.html"))
$RequiredWebFiles = @("index.html", "index.js", "index.wasm", "index.pck")
foreach ($RequiredFile in $RequiredWebFiles) {
    $RequiredPath = Join-Path $WebDirectory $RequiredFile
    if (-not (Test-Path -LiteralPath $RequiredPath -PathType Leaf) -or (Get-Item -LiteralPath $RequiredPath).Length -eq 0) {
        throw "Web export did not create required file: $RequiredPath"
    }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$ZipPath = Join-Path $ArtifactDirectory "block-fighter-web-$Version.zip"
[IO.Compression.ZipFile]::CreateFromDirectory($WebDirectory, $ZipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
$Archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
try {
    $Entries = @($Archive.Entries | ForEach-Object { $_.FullName.Replace("\", "/") })
    foreach ($RequiredFile in $RequiredWebFiles) {
        if ($Entries -notcontains $RequiredFile) {
            throw "ZIP is missing required entry: $RequiredFile"
        }
    }
    $Forbidden = @($Entries | Where-Object { $_ -match '(^|/)(tests|docs|tools|design|build)/' })
    if ($Forbidden.Count -ne 0) {
        throw "ZIP contains non-runtime source: $($Forbidden -join ', ')"
    }
}
finally {
    $Archive.Dispose()
}
$Steps["package"] = [ordered]@{
    exit_code = 0
    started_at_utc = $BuildStartedAt.ToString("o")
    finished_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
    process_log = $null
    engine_log = $null
    assertions = $null
    assertion_failures = 0
    expected_result_marker = "required Web entries and no source-only directories"
    result_marker_found = $true
    unexpected_engine_errors = 0
}
Write-Host "[PASS] package"

$BrowserSmoke = [ordered]@{
    performed = $false
    browser = $null
    browser_exit_code = $null
    browser_termination = $null
    http_index_status = $null
    real_wait_seconds = $null
    page_title = $null
    canvas = $null
    console_error_count = $null
    sampled_unique_colors = $null
    average_luminance = $null
    light_pixel_ratio = $null
    screenshot = $null
    screenshot_sha256 = $null
}
if (-not $SkipBrowserSmoke) {
    $Python = (Get-Command python -ErrorAction Stop).Source
    $EdgeCandidates = @(
        (Join-Path ${env:ProgramFiles(x86)} "Microsoft\Edge\Application\msedge.exe"),
        (Join-Path $env:ProgramFiles "Microsoft\Edge\Application\msedge.exe")
    )
    $EdgePath = $EdgeCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($EdgePath)) {
        throw "Microsoft Edge was not found for the exported Web runtime smoke test."
    }
    $Listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $Listener.Start()
    $Port = ([Net.IPEndPoint]$Listener.LocalEndpoint).Port
    $Listener.Stop()
    $HttpStdout = Join-Path $LogsDirectory "http_server.stdout.log"
    $HttpStderr = Join-Path $LogsDirectory "http_server.stderr.log"
    $ServerStartInfo = [Diagnostics.ProcessStartInfo]::new()
    $ServerStartInfo.FileName = $Python
    $ServerStartInfo.UseShellExecute = $false
    $ServerStartInfo.CreateNoWindow = $true
    $ServerStartInfo.RedirectStandardOutput = $true
    $ServerStartInfo.RedirectStandardError = $true
    foreach ($ServerArgument in @("-m", "http.server", "$Port", "--bind", "127.0.0.1", "--directory", $WebDirectory)) {
        $ServerStartInfo.ArgumentList.Add($ServerArgument)
    }
    $Server = [Diagnostics.Process]::new()
    $Server.StartInfo = $ServerStartInfo
    if (-not $Server.Start()) {
        throw "Could not start the local HTTP server for browser runtime verification."
    }
    $ServerStdoutTask = $Server.StandardOutput.ReadToEndAsync()
    $ServerStderrTask = $Server.StandardError.ReadToEndAsync()
    $EdgeProfile = $null
    $Edge = $null
    $EdgeStdoutTask = $null
    $EdgeStderrTask = $null
    $Socket = $null
    $BrowserStartedAt = $null
    try {
        $Url = "http://127.0.0.1:$Port/index.html"
        $HttpStatus = $null
        for ($Attempt = 0; $Attempt -lt 20; $Attempt++) {
            try {
                $Response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
                $HttpStatus = [int]$Response.StatusCode
                if ($HttpStatus -eq 200) { break }
            }
            catch {
                Start-Sleep -Milliseconds 250
            }
        }
        if ($HttpStatus -ne 200) {
            throw "Exported index.html was not served successfully."
        }
        $ScreenshotPath = Join-Path $RuntimeDirectory "web-runtime.png"
        $EdgeProfile = Join-Path $ReleaseDirectory ".edge-profile"
        $EdgeProcessLog = Join-Path $LogsDirectory "browser_runtime.process.log"
        $DebugListener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $DebugListener.Start()
        $DebugPort = ([Net.IPEndPoint]$DebugListener.LocalEndpoint).Port
        $DebugListener.Stop()
        $EdgeStartInfo = [Diagnostics.ProcessStartInfo]::new()
        $EdgeStartInfo.FileName = $EdgePath
        $EdgeStartInfo.UseShellExecute = $false
        $EdgeStartInfo.CreateNoWindow = $true
        $EdgeStartInfo.RedirectStandardOutput = $true
        $EdgeStartInfo.RedirectStandardError = $true
        foreach ($EdgeArgument in @(
            "--headless=new",
            "--disable-gpu",
            "--disable-background-networking",
            "--no-first-run",
            "--user-data-dir=$EdgeProfile",
            "--window-size=1280,720",
            "--remote-debugging-port=$DebugPort",
            "about:blank"
        )) {
            $EdgeStartInfo.ArgumentList.Add($EdgeArgument)
        }
        $Edge = [Diagnostics.Process]::new()
        $Edge.StartInfo = $EdgeStartInfo
        $BrowserStartedAt = [DateTimeOffset]::UtcNow
        if (-not $Edge.Start()) {
            throw "Could not start Microsoft Edge for Web runtime verification."
        }
        $EdgeStdoutTask = $Edge.StandardOutput.ReadToEndAsync()
        $EdgeStderrTask = $Edge.StandardError.ReadToEndAsync()

        $DevToolsPage = $null
        for ($Attempt = 0; $Attempt -lt 40; $Attempt++) {
            try {
                $Pages = Invoke-RestMethod -Uri "http://127.0.0.1:$DebugPort/json/list" -TimeoutSec 2
                $DevToolsPage = $Pages | Where-Object { $_.type -eq "page" } | Select-Object -First 1
                if ($null -ne $DevToolsPage) { break }
            }
            catch {
                Start-Sleep -Milliseconds 250
            }
        }
        if ($null -eq $DevToolsPage) {
            throw "Microsoft Edge DevTools endpoint did not become ready."
        }
        $Socket = [Net.WebSockets.ClientWebSocket]::new()
        $Socket.ConnectAsync(
            [Uri]$DevToolsPage.webSocketDebuggerUrl,
            [Threading.CancellationToken]::None
        ).GetAwaiter().GetResult() | Out-Null
        $CdpCommandId = 0
        $CdpEvents = [Collections.Generic.List[object]]::new()
        Invoke-CdpCommand -Socket $Socket -CommandId ([ref]$CdpCommandId) -Method "Page.enable" -Events $CdpEvents | Out-Null
        Invoke-CdpCommand -Socket $Socket -CommandId ([ref]$CdpCommandId) -Method "Runtime.enable" -Events $CdpEvents | Out-Null
        Invoke-CdpCommand -Socket $Socket -CommandId ([ref]$CdpCommandId) -Method "Log.enable" -Events $CdpEvents | Out-Null
        Invoke-CdpCommand -Socket $Socket -CommandId ([ref]$CdpCommandId) -Method "Page.navigate" -Parameters @{ url = $Url } -Events $CdpEvents | Out-Null
        $RealWaitSeconds = 30
        Start-Sleep -Seconds $RealWaitSeconds

        $StateExpression = 'JSON.stringify({title:document.title,canvasCount:document.querySelectorAll("canvas").length,canvas:(()=>{const c=document.querySelector("canvas");return c?{width:c.width,height:c.height,clientWidth:c.clientWidth,clientHeight:c.clientHeight}:null})()})'
        $StateResult = Invoke-CdpCommand -Socket $Socket -CommandId ([ref]$CdpCommandId) -Method "Runtime.evaluate" -Parameters @{
            expression = $StateExpression
            returnByValue = $true
        } -Events $CdpEvents
        $PageState = $StateResult.result.value | ConvertFrom-Json
        if ($PageState.title -ne "Block Fighter" -or $PageState.canvasCount -ne 1 -or $PageState.canvas.width -le 0 -or $PageState.canvas.height -le 0) {
            throw "Exported game did not reach the expected Block Fighter canvas state."
        }
        $ScreenshotResult = Invoke-CdpCommand -Socket $Socket -CommandId ([ref]$CdpCommandId) -Method "Page.captureScreenshot" -Parameters @{
            format = "png"
            fromSurface = $true
            captureBeyondViewport = $false
        } -Events $CdpEvents
        [IO.File]::WriteAllBytes($ScreenshotPath, [Convert]::FromBase64String($ScreenshotResult.data))
        if (-not (Test-Path -LiteralPath $ScreenshotPath -PathType Leaf) -or (Get-Item -LiteralPath $ScreenshotPath).Length -lt 10000) {
            throw "Browser runtime did not create a usable screenshot."
        }
        $VisualMetrics = Get-PngVisualMetrics $ScreenshotPath
        if ($VisualMetrics.average_luminance -lt 100.0 -or $VisualMetrics.light_pixel_ratio -lt 0.35) {
            throw "Browser screenshot is still on a dark loading screen: average luminance $($VisualMetrics.average_luminance), light pixel ratio $($VisualMetrics.light_pixel_ratio)."
        }
        $ConsoleErrors = @($CdpEvents | Where-Object {
            $IsException = $_.method -eq "Runtime.exceptionThrown"
            $IsConsoleError = $_.method -eq "Runtime.consoleAPICalled" -and $_.params.type -eq "error"
            $IsLogError = $_.method -eq "Log.entryAdded" -and $_.params.entry.level -eq "error"
            $IsException -or $IsConsoleError -or $IsLogError
        })
        $CdpEvents | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $LogsDirectory "browser_runtime.cdp.log") -Encoding utf8NoBOM
        if ($ConsoleErrors.Count -ne 0) {
            throw "Browser runtime reported $($ConsoleErrors.Count) console error(s)."
        }
        $Steps["browser_runtime"] = [ordered]@{
            exit_code = 0
            started_at_utc = $BrowserStartedAt.ToString("o")
            finished_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
            process_log = Get-RelativeEvidencePath $EdgeProcessLog
            engine_log = $null
            assertions = 3
            assertion_failures = 0
            expected_result_marker = "Block Fighter title, one non-empty canvas, non-blank screenshot"
            result_marker_found = $true
            unexpected_engine_errors = 0
        }
        $BrowserSmoke.performed = $true
        $BrowserSmoke.browser = $EdgePath
        $BrowserSmoke.browser_termination = "controlled_after_evidence_capture"
        $BrowserSmoke.http_index_status = $HttpStatus
        $BrowserSmoke.real_wait_seconds = $RealWaitSeconds
        $BrowserSmoke.page_title = $PageState.title
        $BrowserSmoke.canvas = $PageState.canvas
        $BrowserSmoke.console_error_count = $ConsoleErrors.Count
        $BrowserSmoke.sampled_unique_colors = $VisualMetrics.sampled_unique_colors
        $BrowserSmoke.average_luminance = $VisualMetrics.average_luminance
        $BrowserSmoke.light_pixel_ratio = $VisualMetrics.light_pixel_ratio
        $BrowserSmoke.screenshot = Get-RelativeEvidencePath $ScreenshotPath
        $BrowserSmoke.screenshot_sha256 = Get-Sha256 $ScreenshotPath
        Write-Host "[PASS] browser_runtime"
    }
    finally {
        if ($null -ne $Socket) {
            $Socket.Dispose()
        }
        if ($null -ne $Edge -and -not $Edge.HasExited) {
            $Edge.Kill($true)
            $Edge.WaitForExit()
        }
        if ($null -ne $EdgeStdoutTask -and $null -ne $EdgeStderrTask) {
            $EdgeOutput = $EdgeStdoutTask.GetAwaiter().GetResult()
            $EdgeError = $EdgeStderrTask.GetAwaiter().GetResult()
            [IO.File]::WriteAllText($EdgeProcessLog, "$EdgeOutput`n[stderr]`n$EdgeError", [Text.UTF8Encoding]::new($false))
        }
        if ($null -ne $Server -and -not $Server.HasExited) {
            $Server.Kill($true)
            $Server.WaitForExit()
        }
        [IO.File]::WriteAllText($HttpStdout, $ServerStdoutTask.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($HttpStderr, $ServerStderrTask.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
        if (-not [string]::IsNullOrWhiteSpace($EdgeProfile) -and (Test-Path -LiteralPath $EdgeProfile)) {
            Remove-Item -LiteralPath $EdgeProfile -Recurse -Force
        }
    }
}

$Artifact = Get-Item -LiteralPath $ZipPath
if ($Artifact.LastWriteTimeUtc -lt $BuildStartedAt.UtcDateTime) {
    throw "Artifact timestamp predates this release build."
}
$BuildFinishedAt = [DateTimeOffset]::UtcNow
$ManifestPath = Join-Path $ReleaseDirectory "release-manifest.json"
$Manifest = [ordered]@{
    schema_version = 1
    status = "PASS"
    release = [ordered]@{
        version = $Version
        tag = if ($AllowUntagged) { $null } else { $ExpectedTag }
        commit = $Commit
        short_commit = $ShortCommit
        source_clean = $true
        annotated_tag_verified = (-not $AllowUntagged)
    }
    build = [ordered]@{
        release_id = $ReleaseId
        started_at_utc = $BuildStartedAt.ToString("o")
        finished_at_utc = $BuildFinishedAt.ToString("o")
        godot_version = $GodotVersion
        godot_executable = $GodotPath
        release_script_sha256 = Get-Sha256 $PSCommandPath
        output_directory_cleaned_before_build = $true
    }
    verification = [ordered]@{
        steps = $Steps
        browser_smoke = $BrowserSmoke
    }
    artifacts = @(
        [ordered]@{
            file = Get-RelativeEvidencePath $ZipPath
            size_bytes = $Artifact.Length
            created_at_utc = $Artifact.CreationTimeUtc.ToString("o")
            modified_at_utc = $Artifact.LastWriteTimeUtc.ToString("o")
            sha256 = Get-Sha256 $ZipPath
        }
    )
}
$Manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ManifestPath -Encoding utf8NoBOM

$ChecksumPath = Join-Path $ReleaseDirectory "SHA256SUMS"
$EvidenceFiles = @($ZipPath, $ManifestPath)
$EvidenceFiles += Get-ChildItem -LiteralPath $LogsDirectory -File | Select-Object -ExpandProperty FullName
if ($BrowserSmoke.performed) {
    $EvidenceFiles += Join-Path $ReleaseDirectory $BrowserSmoke.screenshot
}
$ChecksumLines = foreach ($EvidenceFile in ($EvidenceFiles | Sort-Object -Unique)) {
    "$(Get-Sha256 $EvidenceFile)  $(Get-RelativeEvidencePath $EvidenceFile)"
}
$ChecksumLines | Set-Content -LiteralPath $ChecksumPath -Encoding ascii

foreach ($ChecksumLine in Get-Content -LiteralPath $ChecksumPath) {
    if ($ChecksumLine -notmatch '^([0-9a-f]{64})  (.+)$') {
        throw "Invalid SHA256SUMS line: $ChecksumLine"
    }
    $ExpectedHash = $Matches[1]
    $EvidencePath = Join-Path $ReleaseDirectory $Matches[2]
    if ((Get-Sha256 $EvidencePath) -ne $ExpectedHash) {
        throw "Checksum verification failed for $EvidencePath"
    }
}

Write-Host ""
Write-Host "RELEASE PASS"
Write-Host "Version:  $Version"
Write-Host "Commit:   $Commit"
Write-Host "Tag:      $(if ($AllowUntagged) { '<provisional>' } else { $ExpectedTag })"
Write-Host "Artifact: $ZipPath"
Write-Host "SHA-256:  $((Get-Sha256 $ZipPath))"
Write-Host "Evidence: $ReleaseDirectory"
