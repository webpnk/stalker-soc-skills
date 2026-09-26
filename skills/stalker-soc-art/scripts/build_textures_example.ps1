# Example texture build (copy to <root>\src\art\textures\build_textures.ps1). Saved as UTF-8 with BOM
# because it contains Cyrillic.
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\texlib.ps1"
Init-Tex "mod"                                   # your prefix: textures\<prefix>\...
Cloth "cloth_black" 22 20 22 10 1
Cloth "cloth_grey" 162 162 158 16 2
Cloth "cloth_ranger" 58 62 44 16 3
Cloth "cloth_brown" 104 78 52 18 4
Cloth "cloth_pale" 182 190 172 12 11
Solid "void" 0 0 0
Metal "gold"
TextBoard "sign_welcome" "Добро пожаловать!" 512 256 -size 56