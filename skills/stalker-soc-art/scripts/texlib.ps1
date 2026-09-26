# Texture library for SoC mods: draw with System.Drawing, convert to DDS with texconv.
# Dot-source it from a build script in <root>\src\art\textures\:
#   . "$PSScriptRoot\..\texlib.ps1"; Init-Tex "mymod"      # -> gamedata\textures\mymod\
#   Cloth "cloth_grey" 162 162 158 16 2                      # -> texture name mymod\mymod_cloth_grey
# File names are forced to <folder>_<name>: blender-xray only keeps the folder in the texture name it
# writes into an OGF when the file name starts with "<folder>_" (for textures outside its textures
# folder, i.e. everything in the mod). Otherwise the OGF gets a bare name and the game crashes with
# "Can't find texture".
# A .ps1 containing Cyrillic text must be saved as UTF-8 WITH BOM (Windows PowerShell 5.1 reads BOM-less
# files in the ANSI code page and garbles the strings).
Add-Type -AssemblyName System.Drawing
$script:TexRoot = (Resolve-Path "$PSScriptRoot\..\..").Path

function Init-Tex([string]$Folder) {
    $script:TexFolder = $Folder
    $script:TexWork = "$TexRoot\work\textures"
    $script:TexOut = "$TexRoot\game\gamedata\textures\$Folder"
    $script:Texconv = Get-ChildItem "$TexRoot\tools" -Recurse -Filter texconv.exe | Select-Object -First 1 -ExpandProperty FullName
    if (-not $Texconv) { throw "texconv.exe not found under $TexRoot\tools" }
    New-Item -ItemType Directory -Force $TexWork, $TexOut | Out-Null
}

# BC1 = opaque (DXT1); BC3 = with alpha (DXT5). Mips are generated (omit -m). Sizes: powers of two.
function Save-Dds([System.Drawing.Bitmap]$bmp, [string]$name, [string]$format = "BC1_UNORM") {
    if (-not $name.StartsWith($TexFolder + "_")) { $name = $TexFolder + "_" + $name }
    $png = "$TexWork\$name.png"
    $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    & $Texconv -nologo -f $format -y -o $TexOut $png | Out-Null
    "texture $TexFolder\$name ($format)"
}

# woven cloth: base colour + fine weave + fibre noise + soft large-scale fading
function Cloth([string]$name, [int]$r, [int]$g, [int]$b, [double]$noise = 18, [int]$seed = 1) {
    $s = 256
    $bmp = New-Object System.Drawing.Bitmap $s, $s
    $rnd = New-Object System.Random $seed
    $fade = @(); for ($i = 0; $i -lt 9; $i++) { $row = New-Object 'double[]' 9; for ($j = 0; $j -lt 9; $j++) { $row[$j] = $rnd.NextDouble() }; $fade += ,$row }
    for ($y = 0; $y -lt $s; $y++) {
        for ($x = 0; $x -lt $s; $x++) {
            $weave = if ((($x % 4) -lt 2) -xor (($y % 4) -lt 2)) { 6 } else { -6 }
            $fx = $x / $s * 8; $fy = $y / $s * 8; $ix = [int][Math]::Floor($fx); $iy = [int][Math]::Floor($fy)
            $tx = $fx - $ix; $ty = $fy - $iy
            $f0 = $fade[$ix][$iy] * (1 - $tx) + $fade[$ix + 1][$iy] * $tx
            $f1 = $fade[$ix][$iy + 1] * (1 - $tx) + $fade[$ix + 1][$iy + 1] * $tx
            $fd = (($f0 * (1 - $ty) + $f1 * $ty) - 0.5) * 24
            $n = ($rnd.NextDouble() - 0.5) * $noise + $weave + $fd
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255,
                [Math]::Max(0, [Math]::Min(255, [int]($r + $n))),
                [Math]::Max(0, [Math]::Min(255, [int]($g + $n))),
                [Math]::Max(0, [Math]::Min(255, [int]($b + $n)))))
        }
    }
    Save-Dds $bmp $name
}

# polished metal with soft banding (reads as metal on small objects: rings, buckles)
function Metal([string]$name, [int]$r = 200, [int]$g = 150, [int]$b = 40) {
    $s = 128
    $bmp = New-Object System.Drawing.Bitmap $s, $s
    for ($y = 0; $y -lt $s; $y++) {
        $t = [Math]::Sin($y / $s * [Math]::PI * 4) * 0.5 + 0.5
        $c = [System.Drawing.Color]::FromArgb(255, [Math]::Min(255, [int]($r + 55 * $t)), [Math]::Min(255, [int]($g + 60 * $t)), [Math]::Min(255, [int]($b + 50 * $t)))
        for ($x = 0; $x -lt $s; $x++) { $bmp.SetPixel($x, $y, $c) }
    }
    Save-Dds $bmp $name
}

function Solid([string]$name, [int]$r, [int]$g, [int]$b) {
    $bmp = New-Object System.Drawing.Bitmap 16, 16
    for ($y = 0; $y -lt 16; $y++) { for ($x = 0; $x -lt 16; $x++) { $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $r, $g, $b)) } }
    Save-Dds $bmp $name
}

# centred text filling a box, with a soft shadow (fonts with Cyrillic: Georgia, Arial, Times New Roman)
function Draw-Text($g, [string]$text, [string]$font, [System.Drawing.RectangleF]$box, $color, [float]$size) {
    $f = New-Object System.Drawing.Font $font, $size, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = "Center"; $fmt.LineAlignment = "Center"
    $shadow = New-Object System.Drawing.RectangleF ($box.X + 3), ($box.Y + 3), $box.Width, $box.Height
    $g.DrawString($text, $f, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(110, 0, 0, 0))), $shadow, $fmt)
    $g.DrawString($text, $f, (New-Object System.Drawing.SolidBrush $color), $box, $fmt)
    $f.Dispose()
}

# a painted board / banner with text: background colour, border, text colour
function TextBoard([string]$name, [string]$text, [int]$w = 1024, [int]$h = 256, $bg = @(236, 222, 180),
                   $border = @(46, 104, 52), $ink = @(150, 30, 24), [float]$size = 72, [string]$font = "Georgia") {
    $b = New-Object System.Drawing.Bitmap $w, $h; $g = [System.Drawing.Graphics]::FromImage($b)
    $g.SmoothingMode = "AntiAlias"; $g.TextRenderingHint = "AntiAliasGridFit"
    $g.Clear([System.Drawing.Color]::FromArgb($bg[0], $bg[1], $bg[2]))
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($border[0], $border[1], $border[2])), 16
    $g.DrawRectangle($pen, 8, 8, $w - 16, $h - 16)
    Draw-Text $g $text $font (New-Object System.Drawing.RectangleF 30, 30, ($w - 60), ($h - 60)) ([System.Drawing.Color]::FromArgb($ink[0], $ink[1], $ink[2])) $size
    $g.Dispose(); Save-Dds $b $name
}