param (
    [string]$Year = $null
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$DataDir = Join-Path $ProjectRoot "data"

if ($Year) {
    $DataFile = Join-Path $DataDir "market_share_$Year.json"
    if (-not (Test-Path $DataFile)) {
        Write-Error "Data file for year $Year not found: $DataFile"
        exit 1
    }
} else {
    $Files = Get-ChildItem -Path $DataDir -Filter "market_share_*.json" | Sort-Object Name
    if ($Files.Count -eq 0) {
        Write-Error "No market_share_<YEAR>.json files found in $DataDir"
        exit 1
    }
    $DataFile = $Files[-1].FullName
}

Write-Host "Loading data dynamically from: $(Split-Path -Leaf $DataFile)"
$jsonContent = Get-Content -Path $DataFile -Raw -Encoding UTF8 | ConvertFrom-Json

function Format-Leaders($leaders, $note) {
    $parts = @()
    if ($note) {
        $parts += "*($note)*"
    }
    $idx = 1
    foreach ($leader in $leaders) {
        $entry = "$idx. **$($leader.name)**"
        if ($leader.share) {
            $entry += " ($($leader.share))"
        }
        if ($leader.note) {
            $entry += " *($($leader.note))*"
        }
        $parts += $entry
        $idx++
    }
    return $parts -join "<br>"
}

$rows = @()
foreach ($sec in $jsonContent.sectors) {
    $secLabel = "**$($sec.name)**"
    if ($sec.subtitle) {
        $secLabel += "<br>($($sec.subtitle))"
    }
    $rev = ($sec.revenue -replace '\$', '\$')
    $gmv = ($sec.gmv -replace '\$', '\$')
    $leadersStr = Format-Leaders $sec.leaders $sec.note
    $rows += "| $secLabel | $rev | $gmv | $leadersStr |"
}

$tableRows = $rows -join "`n"
$totalRevEsc = ($jsonContent.total_revenue -replace '\$', '\$')
$totalGmvEsc = ($jsonContent.total_gmv -replace '\$', '\$')

$highlightsList = @()
foreach ($h in $jsonContent.highlights) {
    $icon = if ($h.icon) { $h.icon } else { "💡" }
    $highlightsList += "* $icon **$($h.title):** $($h.text)"
}
$highlightsStr = $highlightsList -join "`n"

$markdown = @"
<div align="center">
  <img src="assets/banner.svg" alt="Tech Market Size Banner" width="100%" />
</div>

# 🌐 Tech-Market-Size-and-Market-Share 🚀

<p align="center">
  <a href="https://github.com/ishandutta2007/Awesome-Awesome-Awesome"><img src="https://img.shields.io/badge/Awesome-%E2%9C%94-blueviolet?style=flat-square&logo=github" alt="Awesome"/></a>
  <a href="https://discord.gg/jc4xtF58Ve"><img src="https://img.shields.io/badge/Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord" /></a>
  <a href="https://github.com/ishandutta2007"><img alt="GitHub followers" src="https://img.shields.io/github/followers/ishandutta2007?label=Follow" /></a>
</p>

> **A comprehensive open-source database tracking global technology market sizes, industry revenue, and competitive market shares across key sectors including SaaS, Cloud Infrastructure, AI GPUs, E-commerce, and Digital Advertising.**

### 🌊 Global Tech Market Value Flow (Sankey Diagram)

<div align="center">
  <img src="assets/sankey.svg" alt="Tech Market Flow Sankey Diagram" width="100%" />
</div>

<br/>

### 📊 $($jsonContent.title) 📈

| **Sector** | **Global Market Size (Revenue)** | **Estimated GMV** | **Market Leaders & Competitors (Estimated Mean Share %)** |
| :--- | :--- | :--- | :--- |
$tableRows
| **Total Estimated Market** | **$totalRevEsc** | **$totalGmvEsc** | **Combined major tech sectors listed above** |

---

### 🔎 Market Dynamics Highlights 💡
$highlightsStr

---

### 🛠️ Developer Guide & Data Updates

All dataset figures are decoupled into structured JSON files located in [`data/`](data/).

* **To update or add new sectors:** Edit [`data/market_share_2026.json`](data/market_share_2026.json).
* **To regenerate README and Sankey diagram:**
  ``````bash
  # Python
  python scripts/generate_sankey.py --year 2026
  python scripts/generate_readme.py --year 2026

  # PowerShell (Windows native)
  .\scripts\generate_sankey.ps1 -Year 2026
  .\scripts\generate_readme.ps1 -Year 2026
  ``````
* For complete schema guidelines, entity mappings, and contribution rules, read the [**Developer & Contributor Guide (CONTRIBUTING.md)**](CONTRIBUTING.md).
"@

$ReadmePath = Join-Path $ProjectRoot "README.md"
[System.IO.File]::WriteAllText($ReadmePath, $markdown, [System.Text.Encoding]::UTF8)
Write-Host "Successfully generated $(Split-Path -Leaf $ReadmePath) from $(Split-Path -Leaf $DataFile)!"
