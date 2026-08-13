param(
    [Parameter(Mandatory = $true)]
    [string]$InputVideo,
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,
    [int]$FrameCount = 16
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

if (-not (Test-Path -LiteralPath $InputVideo)) {
    throw "Video not found: $InputVideo"
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$player = [System.Windows.Media.MediaPlayer]::new()
$openFrame = [System.Windows.Threading.DispatcherFrame]::new()
$openError = $null
$openedHandler = {
    $openFrame.Continue = $false
}
$failedHandler = {
    param($sender, $eventArgs)
    $script:openError = $eventArgs.ErrorException
    $openFrame.Continue = $false
}
$player.add_MediaOpened($openedHandler)
$player.add_MediaFailed($failedHandler)
$player.Open([System.Uri]::new($InputVideo))
[System.Windows.Threading.Dispatcher]::PushFrame($openFrame)

if ($null -ne $openError) {
    throw $openError
}
if ($player.NaturalVideoWidth -le 0 -or $player.NaturalVideoHeight -le 0) {
    throw "Windows Media Foundation did not return video dimensions."
}
if (-not $player.NaturalDuration.HasTimeSpan) {
    throw "Windows Media Foundation did not return the video duration."
}

$width = $player.NaturalVideoWidth
$height = $player.NaturalVideoHeight
$duration = $player.NaturalDuration.TimeSpan
$player.Play()
$player.Pause()

for ($index = 0; $index -lt $FrameCount; $index++) {
    $ratio = if ($FrameCount -le 1) { 0.5 } else { 0.02 + 0.96 * $index / ($FrameCount - 1) }
    $position = [TimeSpan]::FromTicks([long]($duration.Ticks * $ratio))
    $player.Position = $position
    Start-Sleep -Milliseconds 120

    $visual = [System.Windows.Media.DrawingVisual]::new()
    $context = $visual.RenderOpen()
    $context.DrawVideo($player, [System.Windows.Rect]::new(0, 0, $width, $height))
    $context.Close()
    $bitmap = [System.Windows.Media.Imaging.RenderTargetBitmap]::new(
        $width,
        $height,
        96,
        96,
        [System.Windows.Media.PixelFormats]::Pbgra32
    )
    $bitmap.Render($visual)
    $encoder = [System.Windows.Media.Imaging.PngBitmapEncoder]::new()
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $outputPath = Join-Path $OutputDirectory ("frame_{0:D2}_{1:D6}ms.png" -f $index, [int]$position.TotalMilliseconds)
    $stream = [System.IO.File]::Open($outputPath, [System.IO.FileMode]::Create)
    try {
        $encoder.Save($stream)
    }
    finally {
        $stream.Dispose()
    }
}

$player.Close()
Write-Output ("DurationMs={0}" -f [int]$duration.TotalMilliseconds)
Write-Output ("Size={0}x{1}" -f $width, $height)
Write-Output ("Frames={0}" -f $FrameCount)
