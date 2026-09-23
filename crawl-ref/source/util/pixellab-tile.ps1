<#
.SYNOPSIS
    Generate a 32x32 DCSS-style tile with the PixelLab API (bitforge model).

.DESCRIPTION
    Reads the API key from the PIXELLAB_API_KEY environment variable (never
    put the key in this file). Uses an existing DCSS tile as a style reference
    so the result matches the game's look, and optionally as a starting image
    so the pose lines up (important for player body tiles, which have armour
    drawn on top of them).

.EXAMPLE
    ./util/pixellab-tile.ps1 -Description "monkey man with brown fur and a long tail" `
        -Style rltiles/player/base/gnoll_m.png -Init rltiles/player/base/human_m.png `
        -Out rltiles/player/base/vanara_m.png
#>
param(
    [Parameter(Mandatory)] [string] $Description,
    [Parameter(Mandatory)] [string] $Out,
    [string] $Style,                  # DCSS tile to copy the style of
    [string] $Init,                   # starting image (keeps pose/shape)
    [string] $Palette,                # image whose colours the result must use
    [int]    $InitStrength = 300,     # 1-999: how closely to keep the init image
    [int]    $StyleStrength = 50,     # 0-100
    [int]    $Size = 32,
    [Nullable[int]] $Seed = $null,
    [string] $Negative = "blurry, text, border, frame, background scenery"
)

$ErrorActionPreference = 'Stop'   # never write a file if the request failed

$key = $env:PIXELLAB_API_KEY
if (-not $key) { $key = [Environment]::GetEnvironmentVariable('PIXELLAB_API_KEY', 'User') }
if (-not $key) { throw "Set the PIXELLAB_API_KEY environment variable first." }

function ImageArg([string] $path) {
    @{ type = 'base64'; format = 'png'
       base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $path))) }
}

$body = @{
    description          = "$Description, dungeon crawl stone soup style roguelike tile"
    negative_description = $Negative
    image_size           = @{ width = $Size; height = $Size }
    no_background        = $true
    outline              = 'single color black outline'
    shading              = 'medium shading'
    detail               = 'medium detail'
    view                 = 'side'
    text_guidance_scale  = 8
}
if ($Style) { $body.style_image = ImageArg $Style; $body.style_strength = $StyleStrength }
if ($Init)  { $body.init_image  = ImageArg $Init;  $body.init_image_strength = $InitStrength }
if ($Palette) { $body.color_image = ImageArg $Palette }
if ($null -ne $Seed) { $body.seed = $Seed }

$resp = Invoke-RestMethod -Method Post -Uri 'https://api.pixellab.ai/v2/create-image-bitforge' `
    -Headers @{ Authorization = "Bearer $key" } -ContentType 'application/json' `
    -Body ($body | ConvertTo-Json -Depth 5)

$dir = Split-Path -Parent $Out
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
[IO.File]::WriteAllBytes($Out, [Convert]::FromBase64String($resp.image.base64))
"saved $Out"
