# Generates the natural-green app icon (1024x1024 PNG) used by Assets.xcassets.
Add-Type -AssemblyName System.Drawing

$size = 1024
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
$deep = [System.Drawing.Color]::FromArgb(255, 18, 53, 39)
$moss = [System.Drawing.Color]::FromArgb(255, 78, 140, 116)
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $deep, $moss, 55.0)
$g.FillRectangle($bg, $rect)

# soft glow in the upper-left corner
$glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$glowPath.AddEllipse(-260, -300, 900, 900)
$glowBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($glowPath)
$glowBrush.CenterColor = [System.Drawing.Color]::FromArgb(70, 190, 224, 190)
$glowBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 190, 224, 190))
$g.FillPath($glowBrush, $glowPath)

# inner dial plate
$plate = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(28, 240, 248, 232))
$g.FillEllipse($plate, 132, 132, 760, 760)

$cx = 512.0
$cy = 512.0
$ringRadius = 348.0

# hour ticks (24 hours, major every 6)
for ($i = 0; $i -lt 24; $i++) {
    $angle = ($i * 15.0) - 90.0
    $rad = $angle * [Math]::PI / 180.0
    $major = ($i % 6 -eq 0)
    $outer = $ringRadius
    $inner = $ringRadius - ($(if ($major) { 44 } else { 24 }))
    $alpha = $(if ($major) { 210 } else { 120 })
    $penTick = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($alpha, 242, 248, 235), $(if ($major) { 10 } else { 6 }))
    $penTick.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penTick.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $x1 = $cx + [Math]::Cos($rad) * $inner
    $y1 = $cy + [Math]::Sin($rad) * $inner
    $x2 = $cx + [Math]::Cos($rad) * $outer
    $y2 = $cy + [Math]::Sin($rad) * $outer
    $g.DrawLine($penTick, [float]$x1, [float]$y1, [float]$x2, [float]$y2)
    $penTick.Dispose()
}

# faint guiding ring
$penRing = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(60, 240, 248, 232), 3)
$g.DrawEllipse($penRing, [float]($cx - $ringRadius), [float]($cy - $ringRadius), [float]($ringRadius * 2), [float]($ringRadius * 2))
$penRing.Dispose()

function Draw-Arc {
    param([double]$startHour, [double]$endHour, [System.Drawing.Color]$color, [double]$width)
    $pen = New-Object System.Drawing.Pen($color, [float]$width)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $r = $ringRadius - 2
    $startAngle = ($startHour / 24.0) * 360.0 - 90.0
    $sweep = (($endHour - $startHour) / 24.0) * 360.0
    $g.DrawArc($pen, [float]($cx - $r), [float]($cy - $r), [float]($r * 2), [float]($r * 2), [float]$startAngle, [float]$sweep)
    $pen.Dispose()
}

# planned block (cream) and actual block (sunlit amber, shifted later)
Draw-Arc -startHour 6.0 -endHour 9.5 -color ([System.Drawing.Color]::FromArgb(235, 240, 248, 232)) -width 34
Draw-Arc -startHour 10.0 -endHour 12.5 -color ([System.Drawing.Color]::FromArgb(245, 228, 168, 92)) -width 34

# leaf sprig: stem + two blades
$stemPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235, 214, 238, 214), 18)
$stemPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$stemPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawBezier($stemPen, [float]($cx - 4), [float]($cy + 268), [float]($cx + 6), [float]($cy + 170), [float]($cx + 8), [float]($cy + 80), [float]($cx + 2), [float]($cy + 6))
$stemPen.Dispose()

function New-LeafGeometry {
    param([double]$width, [double]$height)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddBezier(0, 0, -$width, -$height * 0.32, -$width, -$height * 0.72, 0, -$height)
    $path.AddBezier(0, -$height, $width, -$height * 0.72, $width, -$height * 0.32, 0, 0)
    $path.CloseFigure()
    return $path
}

$leafBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 196, 228, 196))
$leafBrushDark = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 152, 199, 162))

$leftLeaf = New-LeafGeometry -width 104 -height 330
$m1 = New-Object System.Drawing.Drawing2D.Matrix
$m1.RotateAt(-38, (New-Object System.Drawing.PointF(0, 0)))
$m1.Translate([float]($cx - 6), [float]($cy + 150), [System.Drawing.Drawing2D.MatrixOrder]::Append)
$leftLeaf.Transform($m1)
$g.FillPath($leafBrush, $leftLeaf)

$rightLeaf = New-LeafGeometry -width 92 -height 300
$m2 = New-Object System.Drawing.Drawing2D.Matrix
$m2.RotateAt(42, (New-Object System.Drawing.PointF(0, 0)))
$m2.Translate([float]($cx + 6), [float]($cy + 170), [System.Drawing.Drawing2D.MatrixOrder]::Append)
$rightLeaf.Transform($m2)
$g.FillPath($leafBrushDark, $rightLeaf)

# center dot
$dot = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 242, 248, 235))
$g.FillEllipse($dot, [float]($cx - 13), [float]($cy + 112), 26, 26)

$outDir = Join-Path $PSScriptRoot "..\Assets.xcassets\AppIcon.appiconset"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outFile = Join-Path $outDir "AppIcon-1024.png"
$bmp.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
Write-Host "wrote $outFile ($((Get-Item $outFile).Length) bytes)"
