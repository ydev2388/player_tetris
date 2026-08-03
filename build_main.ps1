param(
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $GodotCommand) {
        $GodotPath = $GodotCommand.Source
    }
}

if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot 4.7.1 was not found. Pass its path with -GodotPath."
}

$BuildDirectory = Join-Path $ProjectRoot "build"
New-Item -ItemType Directory -Force -Path $BuildDirectory | Out-Null

Write-Host "[1/3] Importing project resources..."
& $GodotPath --headless --path $ProjectRoot --import
if ($LASTEXITCODE -ne 0) { throw "Godot project import failed." }

Write-Host "[2/3] Running main game tests..."
& $GodotPath --headless --path $ProjectRoot --script "res://tests/main_game_test.gd"
if ($LASTEXITCODE -ne 0) { throw "Gameplay integration test failed." }
& $GodotPath --headless --path $ProjectRoot --script "res://start_screen/tests/main_ui_test.gd"
if ($LASTEXITCODE -ne 0) { throw "Start-screen integration test failed." }

Write-Host "[3/3] Exporting Windows Desktop..."
& $GodotPath --headless --path $ProjectRoot --export-release "Windows Desktop" (Join-Path $BuildDirectory "kungfu_tetris_main.exe")
if ($LASTEXITCODE -ne 0) { throw "Windows export failed." }

Write-Host "Build complete."
