param(
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$OriginalAppData = $env:APPDATA
$BuildAppData = Join-Path $ProjectRoot "build\appdata"
New-Item -ItemType Directory -Force -Path $BuildAppData | Out-Null
$env:APPDATA = $BuildAppData

# Godot 4.7.1 can fault while shutting down after a failed user:// log write in
# restricted automation. Inherit a process-local Windows error mode so a native
# fault is reported through the exit code/log instead of opening a modal dialog.
if (-not ("GodotWindowsErrorMode" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class GodotWindowsErrorMode
{
    [DllImport("kernel32.dll")]
    public static extern UInt32 SetErrorMode(UInt32 mode);
}
"@
}
$WindowsErrorMode = [uint32](0x0001 -bor 0x0002 -bor 0x8000)
[GodotWindowsErrorMode]::SetErrorMode($WindowsErrorMode) | Out-Null

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $WorkspaceRoot = Split-Path -Parent $ProjectRoot
    $LocalConsoleGodot = Get-ChildItem -LiteralPath $WorkspaceRoot `
        -Filter "Godot_v4.7.1-stable_win64_console.exe" -File -Recurse -ErrorAction SilentlyContinue `
        | Select-Object -First 1
    $LocalGodot = Get-ChildItem -LiteralPath $WorkspaceRoot `
        -Filter "Godot_v4.7.1-stable_win64.exe" -File -Recurse -ErrorAction SilentlyContinue `
        | Select-Object -First 1
    if ($null -ne $LocalConsoleGodot) {
        $GodotPath = $LocalConsoleGodot.FullName
    } elseif ($null -ne $LocalGodot) {
        $GodotPath = $LocalGodot.FullName
    } else {
        $GodotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $GodotCommand) {
            $GodotPath = $GodotCommand.Source
        }
    }
}

if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot 4.7.1 was not found. Pass its path with -GodotPath."
}

$BuildDirectory = Join-Path $ProjectRoot "build"
New-Item -ItemType Directory -Force -Path $BuildDirectory | Out-Null
$LogFile = Join-Path $BuildDirectory "godot_main.log"
$SmokeLogFile = Join-Path $BuildDirectory "main_smoke.log"
$SmokeEngineLogFile = Join-Path $BuildDirectory "main_smoke_engine.log"

Write-Host "[1/5] Importing main project resources..."
& $GodotPath --headless --log-file $LogFile --path $ProjectRoot --import
if ($LASTEXITCODE -ne 0) {
    throw "Godot project import failed. Check $LogFile."
}

Write-Host "[2/5] Running main gameplay tests..."
& $GodotPath --headless --log-file $LogFile --path $ProjectRoot --script "res://tests/main_game_test.gd"
if ($LASTEXITCODE -ne 0) {
    throw "Gameplay integration test failed. Check $LogFile."
}

Write-Host "[3/5] Running main start-screen tests..."
& $GodotPath --headless --log-file $LogFile --path $ProjectRoot --script "res://start_screen/tests/main_ui_test.gd"
if ($LASTEXITCODE -ne 0) {
    throw "Start-screen integration test failed. Check $LogFile."
}

Write-Host "[4/5] Exporting the Windows x86_64 release..."
$env:APPDATA = $OriginalAppData
$Executable = Join-Path $BuildDirectory "kungfu_tetris_main.exe"
& $GodotPath --headless --log-file $LogFile --path $ProjectRoot `
    --export-release "Windows Desktop" $Executable
if ($LASTEXITCODE -ne 0) {
    throw "Windows export failed. Check the Godot 4.7.1 export templates and $LogFile."
}

if (-not (Test-Path -LiteralPath $Executable)) {
    throw "Export completed but the executable was not found: $Executable"
}

Write-Host "[5/5] Smoke-testing the exported executable..."
$env:APPDATA = $BuildAppData
if (Test-Path -LiteralPath $SmokeEngineLogFile) {
    Remove-Item -LiteralPath $SmokeEngineLogFile -Force
}
$SmokeOutput = @(
    & $Executable --headless --log-file $SmokeEngineLogFile --quit-after 5 2>&1
)
$SmokeExitCode = $LASTEXITCODE
$SmokeLogLines = @("ExitCode: $SmokeExitCode") + $SmokeOutput
$SmokeLogLines | Set-Content -LiteralPath $SmokeLogFile -Encoding utf8
$SmokeOutput | ForEach-Object { Write-Host $_ }
if ($SmokeExitCode -ne 0) {
    throw "Exported executable smoke test failed. Check $SmokeLogFile."
}
$SmokeErrors = $SmokeOutput | Select-String `
    -Pattern "SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script"
$SmokeLogErrors = @()
if (Test-Path -LiteralPath $SmokeEngineLogFile) {
    $SmokeLogErrors = Get-Content -LiteralPath $SmokeEngineLogFile | Select-String `
        -Pattern "SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script"
}
if ($null -ne $SmokeErrors -or $SmokeLogErrors.Count -gt 0) {
    $SmokeErrors | ForEach-Object { Write-Host $_.Line }
    $SmokeLogErrors | ForEach-Object { Write-Host $_.Line }
    throw "Exported executable logged script errors during the smoke test. Check $SmokeLogFile."
}

Write-Host ""
Write-Host "Build complete: $Executable"
