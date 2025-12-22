param(
  [string]$IncomingDir = "incoming",
  [string]$PortfolioDir = "images/portfolio",
  [switch]$CopySnippet,
  [switch]$UpdateHtml
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$incomingPath  = Join-Path $repoRoot $IncomingDir
$portfolioPath = Join-Path $repoRoot $PortfolioDir
$portfolioHtml = Join-Path $repoRoot "portfolio.html"

if (!(Test-Path $incomingPath))  { throw "Can't find incoming folder: $incomingPath" }
if (!(Test-Path $portfolioPath)) { throw "Can't find portfolio folder: $portfolioPath" }

# 1) Find next portfolio number (max + 1)
$existingNums = Get-ChildItem $portfolioPath -File |
  Where-Object { $_.Name -match '^portfolio-(\d+)\.' } |
  ForEach-Object { [int]$Matches[1] }

$startNum = if ($existingNums) { ($existingNums | Measure-Object -Maximum).Maximum + 1 } else { 1 }

Write-Host "Highest portfolio number found: $([int]($startNum - 1))"
Write-Host "Next new image will start at: portfolio-$startNum" -ForegroundColor Green

# 2) Grab incoming images (jpg/jpeg/png/webp), sorted by name
$incoming = Get-ChildItem $incomingPath -File |
  Where-Object { $_.Extension -match '^\.(jpg|jpeg|png|webp)$' } |
  Sort-Object Name

if (!$incoming) {
  Write-Host "No image files found in $incomingPath"
  Write-Host "Drop images into .\incoming (jpg/jpeg/png/webp) and run again."
  exit
}

# 3) Move/rename them to portfolio-XX.ext
$newItems = @()
$n = $startNum

foreach ($f in $incoming) {
  $ext = $f.Extension.ToLower()
  $newName = ("portfolio-{0:00}{1}" -f $n, $ext)  # 44 -> portfolio-44.jpg
  $dest = Join-Path $portfolioPath $newName

  if (Test-Path $dest) {
    throw "Destination already exists: $dest (won't overwrite)"
  }

  Move-Item -LiteralPath $f.FullName -Destination $dest
  $newItems += $newName
  $n++
}

Write-Host ""
Write-Host "Renamed/moved these files:" -ForegroundColor Cyan
$newItems | ForEach-Object { Write-Host " - $_" }

# 4) Build HTML snippet
$snippetLines = @()
foreach ($name in $newItems) {
  $snippetLines += @"
<figure class="portfolio-item">
  <img src="images/portfolio/$name" alt="Tattoo by Alexa" />
  <figcaption>New piece</figcaption>
</figure>
"@
}
$snippet = ($snippetLines -join "`r`n")

if ($CopySnippet) {
  try {
    Set-Clipboard -Value $snippet
    Write-Host ""
    Write-Host "HTML snippet copied to clipboard." -ForegroundColor Green
  } catch {
    Write-Host ""
    Write-Host "Couldn't copy to clipboard. Here's the snippet:" -ForegroundColor Yellow
    Write-Host $snippet
  }
} else {
  Write-Host ""
  Write-Host "HTML snippet (you can copy/paste):" -ForegroundColor Yellow
  Write-Host $snippet
}

# 5) Optional: auto-insert into portfolio.html before a marker
if ($UpdateHtml) {
  if (!(Test-Path $portfolioHtml)) { throw "Can't find portfolio.html at $portfolioHtml" }

  $marker = "<!-- AUTO-APPEND -->"
  $content = Get-Content $portfolioHtml -Raw

  if ($content -notmatch [regex]::Escape($marker)) {
    throw "Marker not found in portfolio.html. Add this where you want inserts: $marker"
  }

  $updated = $content -replace [regex]::Escape($marker), ($snippet + "`r`n`r`n" + $marker)
  Set-Content -Path $portfolioHtml -Value $updated -NoNewline

  Write-Host ""
  Write-Host "Inserted new items into portfolio.html (before AUTO-APPEND marker)." -ForegroundColor Green
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
