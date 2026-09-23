<#
.SYNOPSIS
    Build a preview page for candidate tiles.

.DESCRIPTION
    Every subfolder of the preview folder is one tile being chosen; every PNG
    in it is a candidate. Files starting with "0-" are shown first as
    references (existing DCSS tiles). Writes index.html in the preview folder,
    showing each tile at 32x32 and enlarged with crisp pixels.

.EXAMPLE
    ./util/tile-gallery.ps1              # then open the printed path
#>
param([string] $Root = "$env:USERPROFILE\Pictures\crawl-tiles")

$sections = foreach ($dir in Get-ChildItem $Root -Directory | Sort-Object Name) {
    $cards = foreach ($f in Get-ChildItem $dir.FullName -Filter *.png | Sort-Object Name) {
        $src = "$($dir.Name)/$($f.Name)"
        $label = [IO.Path]::GetFileNameWithoutExtension($f.Name)
        $ref = if ($label.StartsWith('0-')) { ' ref' } else { '' }
        "<figure class='card$ref'><div class='pair'><img class='big' src='$src'><img class='small' src='$src'></div><figcaption>$label</figcaption></figure>"
    }
    "<section><h2>$($dir.Name)</h2><div class='row'>$($cards -join '')</div></section>"
}

$html = @"
<!doctype html>
<html><head><meta charset="utf-8"><title>Crawl Tile Previews</title>
<style>
  body { margin: 0; padding: 16px; background: #1b1b1b; color: #ddd;
         font: 15px system-ui, sans-serif; }
  h1 { font-size: 20px; margin: 0 0 4px; }
  p.note { margin: 0 0 20px; color: #999; }
  h2 { font-size: 16px; margin: 24px 0 8px; color: #fff; }
  .row { display: flex; flex-wrap: wrap; gap: 12px; }
  .card { margin: 0; padding: 10px; background: #2a2a2a; border-radius: 8px;
          border: 2px solid transparent; }
  .card.ref { background: #232323; opacity: .8; }
  .pair { display: flex; align-items: flex-end; gap: 10px;
          background: #3a3226; padding: 8px; border-radius: 4px; }
  img { image-rendering: pixelated; image-rendering: crisp-edges; }
  .big { width: 192px; height: 192px; }
  .small { width: 32px; height: 32px; }
  figcaption { margin-top: 6px; text-align: center; font-weight: 600; }
  .ref figcaption { font-weight: 400; color: #aaa; }
</style></head>
<body>
<h1>Crawl tile previews</h1>
<p class="note">Big = 6x zoom, small = actual size. Greyed cards starting with "0-" are existing DCSS tiles for comparison. Tell Claude which number you want.</p>
$($sections -join "`n")
</body></html>
"@

$out = Join-Path $Root 'index.html'
Set-Content -Path $out -Value $html -Encoding utf8
$out
