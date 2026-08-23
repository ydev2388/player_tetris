param(
    [Parameter(Mandatory = $true)]
    [string]$GeneratedPath,
    [Parameter(Mandatory = $true)]
    [string]$ReferencePath,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$frameSize = 128
$atlasWidth = 1024
$atlasHeight = 896
$climbRowY = 768

function Test-CheckerBackground([System.Drawing.Color]$color) {
    $minimum = [Math]::Min($color.R, [Math]::Min($color.G, $color.B))
    $maximum = [Math]::Max($color.R, [Math]::Max($color.G, $color.B))
    return $minimum -ge 225 -and ($maximum - $minimum) -le 14
}

$generated = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $GeneratedPath))
$reference = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $ReferencePath))
try {
    if ($reference.Width -ne $atlasWidth -or $reference.Height -ne $atlasHeight) {
        throw "Reference atlas must be ${atlasWidth}x${atlasHeight}."
    }

    $scaled = [System.Drawing.Bitmap]::new(
        $atlasWidth,
        $atlasHeight,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $scaleGraphics = [System.Drawing.Graphics]::FromImage($scaled)
    try {
        $scaleGraphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $scaleGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $scaleGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $scaleGraphics.DrawImage(
            $generated,
            [System.Drawing.Rectangle]::new(0, 0, $atlasWidth, $atlasHeight)
        )
    }
    finally {
        $scaleGraphics.Dispose()
    }

    $output = [System.Drawing.Bitmap]::new(
        $atlasWidth,
        $atlasHeight,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $outputGraphics = [System.Drawing.Graphics]::FromImage($output)
    try {
        $outputGraphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $outputGraphics.DrawImageUnscaled($reference, 0, 0)
    }
    finally {
        $outputGraphics.Dispose()
    }

    $transparentPixel = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
    for ($y = $climbRowY; $y -lt $atlasHeight; $y++) {
        for ($x = 0; $x -lt $atlasWidth; $x++) {
            $output.SetPixel($x, $y, $transparentPixel)
        }
    }

    # Remove only the light checker connected to each cell boundary. This keeps
    # enclosed white shoe/highlight pixels while recovering genuine alpha around limbs.
    for ($frame = 0; $frame -lt 8; $frame++) {
        $cellLeft = $frame * $frameSize
        $visited = [bool[,]]::new($frameSize, $frameSize)
        $queue = [System.Collections.Generic.Queue[System.Drawing.Point]]::new()

        for ($offset = 0; $offset -lt $frameSize; $offset++) {
            $queue.Enqueue([System.Drawing.Point]::new($offset, 0))
            $queue.Enqueue([System.Drawing.Point]::new($offset, $frameSize - 1))
            $queue.Enqueue([System.Drawing.Point]::new(0, $offset))
            $queue.Enqueue([System.Drawing.Point]::new($frameSize - 1, $offset))
        }

        while ($queue.Count -gt 0) {
            $point = $queue.Dequeue()
            if ($visited[$point.X, $point.Y]) {
                continue
            }
            $visited[$point.X, $point.Y] = $true
            $sourceColor = $scaled.GetPixel($cellLeft + $point.X, $climbRowY + $point.Y)
            if (-not (Test-CheckerBackground $sourceColor)) {
                continue
            }
            if ($point.X -gt 0) {
                $queue.Enqueue([System.Drawing.Point]::new($point.X - 1, $point.Y))
            }
            if ($point.X + 1 -lt $frameSize) {
                $queue.Enqueue([System.Drawing.Point]::new($point.X + 1, $point.Y))
            }
            if ($point.Y -gt 0) {
                $queue.Enqueue([System.Drawing.Point]::new($point.X, $point.Y - 1))
            }
            if ($point.Y + 1 -lt $frameSize) {
                $queue.Enqueue([System.Drawing.Point]::new($point.X, $point.Y + 1))
            }
        }

        $generatedMinX = $frameSize
        $generatedMinY = $frameSize
        $generatedMaxX = -1
        $generatedMaxY = -1
        for ($localY = 0; $localY -lt $frameSize; $localY++) {
            for ($localX = 0; $localX -lt $frameSize; $localX++) {
                if ($visited[$localX, $localY]) {
                    continue
                }
                $generatedMinX = [Math]::Min($generatedMinX, $localX)
                $generatedMinY = [Math]::Min($generatedMinY, $localY)
                $generatedMaxX = [Math]::Max($generatedMaxX, $localX)
                $generatedMaxY = [Math]::Max($generatedMaxY, $localY)
            }
        }

        $referenceMinX = $frameSize
        $referenceMaxX = -1
        $referenceMaxY = -1
        for ($localY = 0; $localY -lt $frameSize; $localY++) {
            for ($localX = 0; $localX -lt $frameSize; $localX++) {
                if ($reference.GetPixel($cellLeft + $localX, $climbRowY + $localY).A -lt 26) {
                    continue
                }
                $referenceMinX = [Math]::Min($referenceMinX, $localX)
                $referenceMaxX = [Math]::Max($referenceMaxX, $localX)
                $referenceMaxY = [Math]::Max($referenceMaxY, $localY)
            }
        }

        if ($generatedMaxX -lt 0 -or $referenceMaxX -lt 0) {
            throw "Frame $frame has no visible pixels to align."
        }
        $generatedCenterX = ($generatedMinX + $generatedMaxX) * 0.5
        $referenceCenterX = ($referenceMinX + $referenceMaxX) * 0.5
        $offsetX = [int][Math]::Round($referenceCenterX - $generatedCenterX)
        $offsetY = $referenceMaxY - $generatedMaxY

        for ($localY = 0; $localY -lt $frameSize; $localY++) {
            for ($localX = 0; $localX -lt $frameSize; $localX++) {
                if ($visited[$localX, $localY]) {
                    continue
                }
                $destinationX = $localX + $offsetX
                $destinationY = $localY + $offsetY
                if (
                    $destinationX -lt 0 -or
                    $destinationX -ge $frameSize -or
                    $destinationY -lt 0 -or
                    $destinationY -ge $frameSize
                ) {
                    continue
                }
                $color = $scaled.GetPixel($cellLeft + $localX, $climbRowY + $localY)
                $output.SetPixel(
                    $cellLeft + $destinationX,
                    $climbRowY + $destinationY,
                    $color
                )
            }
        }
    }

    $output.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $output.Dispose()
    $scaled.Dispose()
}
finally {
    $reference.Dispose()
    $generated.Dispose()
}
