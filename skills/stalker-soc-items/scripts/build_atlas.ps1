# Composites src\art\icons\png\<item>.png into a copy of the vanilla inventory icon atlas at the cells
# listed in src\art\icons\icons.json, then writes game\gamedata\textures\ui\ui_icon_equipment.dds
# (BC3/DXT5, no mips, like vanilla). Refuses to paste over non-empty vanilla pixels unless the entry
# has "overwrite": true. Prints the inv_grid_* lines for each item section.
#   icons.json: { "mymod_letter": {"x": 0, "y": 36, "w": 1, "h": 1}, ... }   (cells: 50x50 px)
# Free area in the SoC 1.0006 atlas (1024x2048): rows 37-39 all columns; row 36 except columns 3-4;
# rows 27-35 columns 12-19.
param([string]$Texconv)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
$here = "$root\src\art\icons"
if (-not $Texconv) { $Texconv = Get-ChildItem "$root\tools" -Recurse -Filter texconv.exe | Select-Object -First 1 -ExpandProperty FullName }
if (-not $Texconv) { throw "texconv.exe not found under $root\tools (github.com/microsoft/DirectXTex releases)" }
$work = "$root\work\icons"
New-Item -ItemType Directory -Force $work | Out-Null
Add-Type -AssemblyName System.Drawing

& $Texconv -nologo -ft png -y -o $work "$root\unpacked\textures\ui\ui_icon_equipment.dds" | Out-Null
$icons = Get-Content "$here\icons.json" -Raw | ConvertFrom-Json

$atlas = [System.Drawing.Bitmap]::FromFile("$work\ui_icon_equipment.png")
$canvas = New-Object System.Drawing.Bitmap $atlas.Width, $atlas.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.DrawImage($atlas, 0, 0, $atlas.Width, $atlas.Height)
$atlas.Dispose()
$g.CompositingMode = "SourceCopy"
$g.InterpolationMode = "HighQualityBicubic"
$g.PixelOffsetMode = "HighQuality"

foreach ($p in $icons.PSObject.Properties) {
    $n = $p.Name; $c = $p.Value
    $x = $c.x * 50; $y = $c.y * 50; $w = $c.w * 50; $h = $c.h * 50
    for ($yy = $y; $yy -lt $y + $h; $yy += 4) { for ($xx = $x; $xx -lt $x + $w; $xx += 4) {
        if ($canvas.GetPixel($xx, $yy).A -gt 10 -and -not $c.overwrite) { throw "$n : cell ($($c.x),$($c.y)) is not empty in the vanilla atlas" } } }
    $src = "$here\png\$n.png"
    if (-not (Test-Path $src)) { throw "missing icon $src (transparent PNG, any size; drawn into $w x $h px)" }
    $img = [System.Drawing.Image]::FromFile($src)
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle $x, $y, $w, $h))
    $img.Dispose()
    "[{0}]  inv_grid_x = {1}  inv_grid_y = {2}  inv_grid_width = {3}  inv_grid_height = {4}" -f $n, $c.x, $c.y, $c.w, $c.h
}
$g.Dispose()
$canvas.Save("$work\ui_icon_equipment.png", [System.Drawing.Imaging.ImageFormat]::Png)
$canvas.Dispose()
$outDir = "$root\game\gamedata\textures\ui"
New-Item -ItemType Directory -Force $outDir | Out-Null
& $Texconv -nologo -f BC3_UNORM -m 1 -y -o $outDir "$work\ui_icon_equipment.png" | Select-Object -Last 1
