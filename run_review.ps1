param(
    [string]$Executable = "",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$PassThroughArguments = @()
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$BuildDirectory = Join-Path $ProjectRoot "build"
New-Item -ItemType Directory -Force -Path $BuildDirectory | Out-Null

if ([string]::IsNullOrWhiteSpace($Executable)) {
    $Executable = Join-Path $BuildDirectory "kungfu_tetris_main.exe"
}
if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
    throw "Review executable was not found: $Executable"
}
$Executable = (Resolve-Path -LiteralPath $Executable).Path
$LogFile = Join-Path $BuildDirectory "review_run.log"
if (Test-Path -LiteralPath $LogFile) {
    Remove-Item -LiteralPath $LogFile -Force
}

# Suppress the Windows native-crash dialog only for this launcher and the game
# process it creates. Failures remain observable through the exit code and log.
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

$ArgumentParts = @("--log-file", ('"{0}"' -f $LogFile))
foreach ($Argument in $PassThroughArguments) {
    $ArgumentParts += ('"{0}"' -f $Argument.Replace('"', '\"'))
}

$StartInfo = New-Object System.Diagnostics.ProcessStartInfo
$StartInfo.FileName = $Executable
$StartInfo.Arguments = $ArgumentParts -join " "
$StartInfo.UseShellExecute = $false
$Process = [System.Diagnostics.Process]::Start($StartInfo)
$Process.WaitForExit()
$ReviewExitCode = $Process.ExitCode
$ReviewErrors = @()
if (Test-Path -LiteralPath $LogFile) {
    $ReviewErrors = Get-Content -LiteralPath $LogFile | Select-String `
        -Pattern "SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed to load script"
}
if ($ReviewErrors.Count -gt 0) {
    $ReviewErrors | ForEach-Object { Write-Host $_.Line }
    exit 1
}
exit $ReviewExitCode
