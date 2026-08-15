param (
    [string]$Year = "2026",
    [string]$Output = "assets/sankey.svg"
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$DataFile = Join-Path $ProjectRoot "data/market_share_$Year.json"
$OutputFile = Join-Path $ProjectRoot $Output

if (-not (Test-Path $DataFile)) {
    Write-Error "Data file not found: $DataFile"
    exit 1
}

$data = Get-Content -Path $DataFile -Raw -Encoding UTF8 | ConvertFrom-Json

function Parse-Val($valStr) {
    if (-not $valStr -or $valStr -eq "-") { return 0.0 }
    $clean = $valStr -replace '~', '' -replace '\$', '' -replace ',', ''
    $clean = $clean.Trim()
    if ($clean -match 'Trillion') {
        $num = [double]($clean -replace 'Trillion', '').Trim()
        return $num * 1000.0
    } elseif ($clean -match 'Billion') {
        $num = [double]($clean -replace 'Billion', '').Trim()
        return $num
    } elseif ($clean -match 'Million') {
        $num = [double]($clean -replace 'Million', '').Trim()
        return $num / 1000.0
    }
    try { return [double]$clean } catch { return 0.0 }
}

function Parse-Pct($pctStr) {
    if (-not $pctStr) { return 0.0 }
    $clean = $pctStr -replace '[~><%]', '' -replace 'each', ''
    $clean = $clean.Trim()
    try { return [double]$clean / 100.0 } catch { return 0.0 }
}

function Bezier-Ribbon($x0, $y0_top, $y0_bot, $x1, $y1_top, $y1_bot) {
    $dx = ($x1 - $x0) * 0.5
    $x0_s = "{0:F1}" -f $x0
    $x1_s = "{0:F1}" -f $x1
    $y0_t_s = "{0:F1}" -f $y0_top
    $y0_b_s = "{0:F1}" -f $y0_bot
    $y1_t_s = "{0:F1}" -f $y1_top
    $y1_b_s = "{0:F1}" -f $y1_bot
    $cx0 = "{0:F1}" -f ($x0 + $dx)
    $cx1 = "{0:F1}" -f ($x1 - $dx)
    return "M $x0_s $y0_t_s C $cx0 $y0_t_s, $cx1 $y1_t_s, $x1_s $y1_t_s L $x1_s $y1_b_s C $cx1 $y1_b_s, $cx0 $y0_b_s, $x0_s $y0_b_s Z"
}

$colors = @("#3b82f6", "#10b981", "#8b5cf6", "#f59e0b", "#ec4899", "#06b6d4", "#14b8a6", "#f97316", "#6366f1", "#84cc16", "#a855f7", "#eab308", "#64748b")

$sectorData = @()
$totalMarketRev = 0.0
$idx = 0
foreach ($sec in $data.sectors) {
    $rev = Parse-Val $sec.revenue
    if ($rev -gt 0) {
        $totalMarketRev += $rev
        $sectorData += [PSCustomObject]@{
            id = $sec.id
            name = $sec.name
            revenue = $rev
            color = $colors[$idx % $colors.Count]
            leaders = $sec.leaders
        }
        $idx++
    }
}

$sectorData = $sectorData | Sort-Object -Property revenue -Descending

$companyTotals = @{}
$flowsSecToComp = @()

$s_idx = 0
foreach ($sec in $sectorData) {
    $accountedPct = 0.0
    foreach ($leader in $sec.leaders) {
        $cleanName = ($leader.name -split ' \(')[0].Trim()
        $pct = Parse-Pct $leader.share
        $flowVal = $sec.revenue * $pct
        $accountedPct += $pct

        if (-not $companyTotals.ContainsKey($cleanName)) { $companyTotals[$cleanName] = 0.0 }
        $companyTotals[$cleanName] += $flowVal

        $flowsSecToComp += [PSCustomObject]@{
            sec_idx = $s_idx
            comp_name = $cleanName
            value = $flowVal
        }
    }
    $unaccountedPct = [Math]::Max(0.0, 1.0 - $accountedPct)
    if ($unaccountedPct -gt 0.01) {
        $otherVal = $sec.revenue * $unaccountedPct
        $otherLabel = "Other ($($sec.name))"
        if (-not $companyTotals.ContainsKey($otherLabel)) { $companyTotals[$otherLabel] = 0.0 }
        $companyTotals[$otherLabel] += $otherVal
        $flowsSecToComp += [PSCustomObject]@{
            sec_idx = $s_idx
            comp_name = $otherLabel
            value = $otherVal
        }
    }
    $s_idx++
}

$sortedComps = $companyTotals.GetEnumerator() | Sort-Object Value -Descending
$topComps = @()
$longTailSum = 0.0
foreach ($item in $sortedComps) {
    if ($item.Value -ge 50.0 -and -not $item.Key.StartsWith("Other (")) {
        $topComps += $item.Key
    } else {
        $longTailSum += $item.Value
    }
}
if ($longTailSum -gt 0) {
    $topComps += "Other Industry Players"
}

$mergedFlows = @{}
foreach ($f in $flowsSecToComp) {
    $target = if ($topComps -contains $f.comp_name) { $f.comp_name } else { "Other Industry Players" }
    $key = "$($f.sec_idx):$target"
    if (-not $mergedFlows.ContainsKey($key)) { $mergedFlows[$key] = 0.0 }
    $mergedFlows[$key] += $f.value
}

$compNodeData = @()
$c_idx = 0
foreach ($c_name in $topComps) {
    $val = 0.0
    for ($i = 0; $i -lt $sectorData.Count; $i++) {
        $k = "$($i):$c_name"
        if ($mergedFlows.ContainsKey($k)) { $val += $mergedFlows[$k] }
    }
    $col = if ($c_name -eq "Other Industry Players") { "#475569" } else { $colors[$c_idx % $colors.Count] }
    $compNodeData += [PSCustomObject]@{
        name = $c_name
        value = $val
        color = $col
    }
    $c_idx++
}

$width = 1200
$height = 850
$marginTop = 80
$marginBottom = 60
$marginLeft = 40
$marginRight = 160
$usableH = $height - $marginTop - $marginBottom
$gapY = 12

$totalGapsCol2 = $gapY * ($sectorData.Count - 1)
$totalGapsCol3 = $gapY * ($compNodeData.Count - 1)
$maxFlowH = $usableH - [Math]::Max($totalGapsCol2, $totalGapsCol3)
$scaleY = $maxFlowH / $totalMarketRev

$wNode = 24
$xCol1 = $marginLeft
$xCol2 = ($width - $marginLeft - $marginRight) * 0.44 + $marginLeft
$xCol3 = $width - $marginRight

$totalNodeH = $totalMarketRev * $scaleY
$yCol1Start = $marginTop + ($usableH - $totalNodeH) / 2.0

$col2Nodes = @()
$currY2 = $marginTop
foreach ($sec in $sectorData) {
    $h = $sec.revenue * $scaleY
    $col2Nodes += [PSCustomObject]@{
        y = $currY2
        h = $h
        data = $sec
        curr_out_y = $currY2
    }
    $currY2 += $h + $gapY
}

$col3Nodes = @{}
$currY3 = $marginTop
foreach ($comp in $compNodeData) {
    $h = $comp.value * $scaleY
    $col3Nodes[$comp.name] = [PSCustomObject]@{
        y = $currY3
        h = $h
        data = $comp
        curr_in_y = $currY3
    }
    $currY3 += $h + $gapY
}

$ribbons = @()
$currOutY1 = $yCol1Start
foreach ($n2 in $col2Nodes) {
    $flowH = $n2.h
    $pathD = Bezier-Ribbon ($xCol1 + $wNode) $currOutY1 ($currOutY1 + $flowH) $xCol2 $n2.y ($n2.y + $flowH)
    $ribbons += [PSCustomObject]@{
        path = $pathD
        color = $n2.data.color
        opacity = "0.35"
        tooltip = "$($n2.data.name): ~`$$("{0:N0}" -f $n2.data.revenue)B"
    }
    $currOutY1 += $flowH
}

for ($s = 0; $s -lt $sectorData.Count; $s++) {
    $n2 = $col2Nodes[$s]
    $sec = $sectorData[$s]
    foreach ($compName in $topComps) {
        $k = "$($s):$compName"
        if ($mergedFlows.ContainsKey($k) -and $mergedFlows[$k] -gt 0.1) {
            $val = $mergedFlows[$k]
            $flowH = $val * $scaleY
            $n3 = $col3Nodes[$compName]
            $pathD = Bezier-Ribbon ($xCol2 + $wNode) $n2.curr_out_y ($n2.curr_out_y + $flowH) $xCol3 $n3.curr_in_y ($n3.curr_in_y + $flowH)
            $ribbons += [PSCustomObject]@{
                path = $pathD
                color = $n2.data.color
                opacity = "0.40"
                tooltip = "$($sec.name) -> $($compName): ~`$$("{0:N1}" -f $val)B"
            }
            $n2.curr_out_y += $flowH
            $n3.curr_in_y += $flowH
        }
    }
}

$totalTStr = "{0:N2}" -f ($totalMarketRev / 1000.0)

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("<svg xmlns=`"http://www.w3.org/2000/svg`" viewBox=`"0 0 $width $height`" width=`"100%`" height=`"100%`" style=`"background:#090d16; border-radius:12px; font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;`">")
[void]$sb.AppendLine("<defs>")
[void]$sb.AppendLine("  <style>")
[void]$sb.AppendLine("    .title { fill: #f8fafc; font-size: 20px; font-weight: 700; }")
[void]$sb.AppendLine("    .subtitle { fill: #94a3b8; font-size: 12px; }")
[void]$sb.AppendLine("    .node-label { fill: #f1f5f9; font-size: 11.5px; font-weight: 600; }")
[void]$sb.AppendLine("    .node-sub { fill: #94a3b8; font-size: 10px; }")
[void]$sb.AppendLine("    .col-header { fill: #38bdf8; font-size: 12px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; }")
[void]$sb.AppendLine("    .ribbon { transition: opacity 0.2s ease; }")
[void]$sb.AppendLine("    .ribbon:hover { opacity: 0.8 !important; }")
[void]$sb.AppendLine("  </style>")
[void]$sb.AppendLine("</defs>")
[void]$sb.AppendLine("<text x=`"$marginLeft`" y=`"36`" class=`"title`">Global Tech Market Flow &amp; Revenue Distribution</text>")
[void]$sb.AppendLine("<text x=`"$marginLeft`" y=`"54`" class=`"subtitle`">Estimated 2025–2026 Annualized Revenue Breakdown (~`$$totalTStr`T Total)</text>")
[void]$sb.AppendLine("<text x=`"$xCol1`" y=`"$($marginTop - 16)`" class=`"col-header`">Total Market</text>")
[void]$sb.AppendLine("<text x=`"$xCol2`" y=`"$($marginTop - 16)`" class=`"col-header`">Tech Sectors</text>")
[void]$sb.AppendLine("<text x=`"$xCol3`" y=`"$($marginTop - 16)`" class=`"col-header`">Leaders &amp; Ecosystem</text>")

[void]$sb.AppendLine("<g class=`"ribbons`">")
foreach ($r in $ribbons) {
    [void]$sb.AppendLine("  <path d=`"$($r.path)`" fill=`"$($r.color)`" opacity=`"$($r.opacity)`" class=`"ribbon`"><title>$($r.tooltip)</title></path>")
}
[void]$sb.AppendLine("</g>")

$yCol1_s = "{0:F1}" -f $yCol1Start
$totH_s = "{0:F1}" -f $totalNodeH
$midY1_t = "{0:F1}" -f ($totalNodeH / 2.0 - 6)
$midY1_b = "{0:F1}" -f ($totalNodeH / 2.0 + 10)
[void]$sb.AppendLine("<g transform=`"translate($xCol1, $yCol1_s)`">")
[void]$sb.AppendLine("  <rect width=`"$wNode`" height=`"$totH_s`" rx=`"4`" fill=`"#38bdf8`" />")
[void]$sb.AppendLine("  <text x=`"$($wNode + 8)`" y=`"$midY1_t`" class=`"node-label`">Global Tech Market</text>")
[void]$sb.AppendLine("  <text x=`"$($wNode + 8)`" y=`"$midY1_b`" class=`"node-sub`">~`$$totalTStr Trillion</text>")
[void]$sb.AppendLine("</g>")

foreach ($n2 in $col2Nodes) {
    $sec = $n2.data
    $vStr = if ($sec.revenue -ge 1000) { "~`$" + ("{0:N2}" -f ($sec.revenue / 1000.0)) + "T" } else { "~`$" + ("{0:N0}" -f $sec.revenue) + "B" }
    $y2_s = "{0:F1}" -f $n2.y
    $h2_s = "{0:F1}" -f $n2.h
    $lblY_t = "{0:F1}" -f [Math]::Max(12.0, [Math]::Min($n2.h / 2.0 - 2, $n2.h - 14))
    $lblY_b = "{0:F1}" -f [Math]::Max(24.0, [Math]::Min($n2.h / 2.0 + 10, $n2.h - 2))
    [void]$sb.AppendLine("<g transform=`"translate($xCol2, $y2_s)`">")
    [void]$sb.AppendLine("  <rect width=`"$wNode`" height=`"$h2_s`" rx=`"3`" fill=`"$($sec.color)`" />")
    [void]$sb.AppendLine("  <text x=`"$($wNode + 8)`" y=`"$lblY_t`" class=`"node-label`">$([System.Security.SecurityElement]::Escape($sec.name))</text>")
    [void]$sb.AppendLine("  <text x=`"$($wNode + 8)`" y=`"$lblY_b`" class=`"node-sub`">$vStr</text>")
    [void]$sb.AppendLine("</g>")
}

foreach ($comp in $compNodeData) {
    $n3 = $col3Nodes[$comp.name]
    $vStr = if ($comp.value -ge 1000) { "~`$" + ("{0:N2}" -f ($comp.value / 1000.0)) + "T" } else { "~`$" + ("{0:N0}" -f $comp.value) + "B" }
    $y3_s = "{0:F1}" -f $n3.y
    $h3_s = "{0:F1}" -f $n3.h
    $lblY_t = "{0:F1}" -f [Math]::Max(11.0, [Math]::Min($n3.h / 2.0 - 2, $n3.h - 12))
    $lblY_b = "{0:F1}" -f [Math]::Max(22.0, [Math]::Min($n3.h / 2.0 + 9, $n3.h - 2))
    [void]$sb.AppendLine("<g transform=`"translate($xCol3, $y3_s)`">")
    [void]$sb.AppendLine("  <rect width=`"$wNode`" height=`"$h3_s`" rx=`"3`" fill=`"$($comp.color)`" />")
    [void]$sb.AppendLine("  <text x=`"$($wNode + 8)`" y=`"$lblY_t`" class=`"node-label`">$([System.Security.SecurityElement]::Escape($comp.name))</text>")
    [void]$sb.AppendLine("  <text x=`"$($wNode + 8)`" y=`"$lblY_b`" class=`"node-sub`">$vStr</text>")
    [void]$sb.AppendLine("</g>")
}

[void]$sb.AppendLine("</svg>")

$OutputFolder = Split-Path -Parent $OutputFile
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

[System.IO.File]::WriteAllText($OutputFile, $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "Successfully generated Sankey Diagram: $(Split-Path -Leaf $OutputFile)!"
