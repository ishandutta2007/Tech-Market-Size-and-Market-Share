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

$CompanyMappings = @{
    "Microsoft" = "Microsoft";
    "Microsoft (Azure)" = "Microsoft";
    "Microsoft (Xbox / ABK)" = "Microsoft";
    "Microsoft (LinkedIn/Bing)" = "Microsoft";
    "Microsoft (Surface)" = "Microsoft";
    "Microsoft (Xbox)" = "Microsoft";
    "Microsoft Azure Quantum" = "Microsoft";
    "Google" = "Alphabet (Google)";
    "Google (Alphabet)" = "Alphabet (Google)";
    "Google (Workspace)" = "Alphabet (Google)";
    "Google Cloud" = "Alphabet (Google)";
    "Google (Gemini)" = "Alphabet (Google)";
    "Google (Play Games)" = "Alphabet (Google)";
    "Google Quantum AI" = "Alphabet (Google)";
    "Amazon" = "Amazon";
    "Amazon (AWS)" = "Amazon";
    "Amazon Ads" = "Amazon";
    "Amazon Business" = "Amazon";
    "Amazon Prime Video" = "Amazon";
    "Amazon Robotics" = "Amazon";
    "Amazon Braket" = "Amazon";
    "Apple" = "Apple";
    "Apple (Mac)" = "Apple";
    "Apple (App Store Games)" = "Apple";
    "Apple (App Store)" = "Apple";
    "Apple Ads" = "Apple";
    "Apple TV+" = "Apple";
    "Meta" = "Meta";
    "Meta (Facebook/Instagram)" = "Meta";
    "Meta (Facebook)" = "Meta";
    "Alibaba" = "Alibaba Group";
    "Alibaba (Taobao/Tmall)" = "Alibaba Group";
    "Alibaba.com" = "Alibaba Group";
    "Alibaba Cloud" = "Alibaba Group";
    "Tencent" = "Tencent";
    "Tencent Cloud" = "Tencent";
    "Tencent Video" = "Tencent";
    "Tencent Video / iQIYI" = "Tencent";
    "Samsung" = "Samsung";
    "Samsung Electronics" = "Samsung";
    "Samsung (Memory/LSI)" = "Samsung";
    "Samsung (Memory)" = "Samsung";
    "Nvidia" = "Nvidia";
    "ByteDance" = "ByteDance";
    "ByteDance (TikTok/Douyin)" = "ByteDance";
    "Douyin E-commerce" = "ByteDance";
    "PDD Holdings" = "PDD Holdings";
    "PDD Holdings (Temu/Pinduoduo)" = "PDD Holdings";
    "JD.com" = "JD.com";
    "OpenAI" = "OpenAI";
    "Anthropic" = "Anthropic";
    "Sony" = "Sony";
    "Sony (PlayStation)" = "Sony";
    "Crunchyroll (Sony)" = "Sony";
    "Netflix" = "Netflix";
    "Lenovo" = "Lenovo";
    "Motorola / Lenovo" = "Lenovo";
    "HP Inc." = "HP Inc.";
    "Dell" = "Dell";
    "Xiaomi" = "Xiaomi";
    "SK Hynix" = "SK Hynix";
    "Broadcom" = "Broadcom";
    "Broadcom (Custom AI XPUs)" = "Broadcom";
    "Qualcomm" = "Qualcomm";
    "Intel" = "Intel";
    "Intel (Gaudi)" = "Intel";
    "AMD" = "AMD";
    "AMD (Instinct)" = "AMD";
    "AMD (Client/Embedded)" = "AMD";
    "Binance" = "Binance";
    "Coinbase" = "Coinbase";
    "Shopify" = "Shopify";
    "Shopify (Merchant Ecosystem)" = "Shopify";
    "Meituan" = "Meituan";
    "Salesforce" = "Salesforce";
    "Oracle" = "Oracle";
    "Oracle Cloud (OCI)" = "Oracle";
    "Oracle Cloud" = "Oracle";
    "SAP" = "SAP";
    "Adobe" = "Adobe";
    "Intuit" = "Intuit";
    "ServiceNow" = "ServiceNow";
    "Workday" = "Workday";
    "Huawei" = "Huawei";
    "Huawei Cloud" = "Huawei";
    "ASUS" = "ASUS";
    "Acer" = "Acer";
    "Oppo" = "Oppo";
    "Vivo" = "Vivo";
    "Honor" = "Honor";
    "Transsion" = "Transsion";
    "Warner Bros (Max)" = "Warner Bros. Discovery";
    "Disney+ / Hulu" = "Disney";
    "Disney+" = "Disney";
    "Micron" = "Micron";
    "MediaTek" = "MediaTek";
    "Texas Instruments" = "Texas Instruments";
    "FANUC" = "FANUC";
    "ABB Robotics" = "ABB";
    "Intuitive Surgical" = "Intuitive Surgical";
    "Midea (KUKA)" = "Midea Group (KUKA)";
    "Yaskawa Electric" = "Yaskawa Electric";
    "DJI (Enterprise/Industrial)" = "DJI";
    "Boston Dynamics / Hyundai" = "Hyundai (Boston Dynamics)";
    "AutoStore / Symbotic" = "AutoStore / Symbotic";
    "Tesla (Optimus / FSD AI)" = "Tesla";
    "Figure AI" = "Figure AI";
    "Unitree Robotics" = "Unitree Robotics";
    "IBM (IBM Quantum)" = "IBM";
    "IBM Cloud" = "IBM";
    "Quantinuum (Honeywell)" = "Honeywell (Quantinuum)";
    "IonQ" = "IonQ";
    "D-Wave Quantum" = "D-Wave Quantum";
    "Rigetti Computing" = "Rigetti"
}

function Escape-Xml([string]$str) {
    if (-not $str) { return "" }
    return [System.Security.SecurityElement]::Escape($str)
}

function Parse-Val($valStr) {
    if (-not $valStr -or $valStr -eq "-") { return 0.0 }
    $clean = "$valStr" -replace '~', '' -replace '\$', '' -replace ',', ''
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
    $clean = "$pctStr" -replace '[~><%]', '' -replace 'each', ''
    $clean = $clean.Trim()
    try { return [double]$clean / 100.0 } catch { return 0.0 }
}

function Bezier-Ribbon($x0, $y0_top, $y0_bot, $x1, $y1_top, $y1_bot) {
    $dx = ($x1 - $x0) * 0.48
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

$palette = @("#f97316", "#38bdf8", "#10b981", "#8b5cf6", "#f59e0b", "#ec4899", "#06b6d4", "#6366f1", "#84cc16", "#a855f7", "#eab308", "#14b8a6", "#0ea5e9", "#d946ef", "#64748b")

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
            subtitle = $sec.subtitle
            revenue = $rev
            color = $palette[$idx % $palette.Count]
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
        $rawName = $leader.name
        $mappedName = if ($CompanyMappings.ContainsKey($rawName)) { $CompanyMappings[$rawName] } else { ($rawName -split ' \(')[0].Trim() }
        $pct = Parse-Pct $leader.share
        $flowVal = $sec.revenue * $pct
        $accountedPct += $pct

        if (-not $companyTotals.ContainsKey($mappedName)) { $companyTotals[$mappedName] = 0.0 }
        $companyTotals[$mappedName] += $flowVal

        $flowsSecToComp += [PSCustomObject]@{
            sec_idx = $s_idx
            comp_name = $mappedName
            value = $flowVal
        }
    }
    $unaccountedPct = [Math]::Max(0.0, 1.0 - $accountedPct)
    if ($unaccountedPct -gt 0.005) {
        $otherVal = $sec.revenue * $unaccountedPct
        $otherLabel = "Other Industry Players"
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
$otherAcc = 0.0
foreach ($item in $sortedComps) {
    if ($item.Key -eq "Other Industry Players") {
        $otherAcc += $item.Value
    } elseif ($item.Value -ge 40.0) {
        $topComps += $item.Key
    } else {
        $otherAcc += $item.Value
    }
}
if ($otherAcc -gt 0) {
    $topComps += "Other Industry Players"
}

$mergedFlows = @{}
foreach ($f in $flowsSecToComp) {
    $target = if ($topComps -contains $f.comp_name) { $f.comp_name } else { "Other Industry Players" }
    $key = "$($f.sec_idx):$target"
    if (-not $mergedFlows.ContainsKey($key)) { $mergedFlows[$key] = 0.0 }
    $mergedFlows[$key] += $f.value
}

$compColors = @(
    "#f97316", "#38bdf8", "#8b5cf6", "#10b981", "#f59e0b",
    "#ec4899", "#06b6d4", "#a855f7", "#84cc16", "#6366f1",
    "#eab308", "#14b8a6", "#f43f5e", "#22d3ee", "#e11d48",
    "#10b981", "#3b82f6", "#f97316", "#8b5cf6"
)

$compNodeData = @()
$c_idx = 0
foreach ($c_name in $topComps) {
    $val = 0.0
    for ($i = 0; $i -lt $sectorData.Count; $i++) {
        $k = "$($i):$c_name"
        if ($mergedFlows.ContainsKey($k)) { $val += $mergedFlows[$k] }
    }
    $col = if ($c_name -eq "Other Industry Players") { "#475569" } else { $compColors[$c_idx % $compColors.Count] }
    $compNodeData += [PSCustomObject]@{
        name = $c_name
        value = $val
        color = $col
    }
    $c_idx++
}

$width = 1440
$height = 1000
$marginTop = 90
$marginBottom = 50
$marginLeft = 30
$marginRight = 260
$usableH = $height - $marginTop - $marginBottom
$gapYSec = 12
$gapYComp = 10

$totalGapsCol2 = $gapYSec * ($sectorData.Count - 1)
$totalGapsCol3 = $gapYComp * ($compNodeData.Count - 1)
$maxFlowH = $usableH - [Math]::Max($totalGapsCol2, $totalGapsCol3)
$scaleY = $maxFlowH / $totalMarketRev

$wNode = 20
$xCol1 = $marginLeft
$xCol2 = 540
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
    $currY2 += $h + $gapYSec
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
    $currY3 += $h + $gapYComp
}

$ribbons = @()
$currOutY1 = $yCol1Start
foreach ($n2 in $col2Nodes) {
    $flowH = $n2.h
    $pathD = Bezier-Ribbon ($xCol1 + $wNode) $currOutY1 ($currOutY1 + $flowH) $xCol2 $n2.y ($n2.y + $flowH)
    $ribbons += [PSCustomObject]@{
        path = $pathD
        color = $n2.data.color
        opacity = "0.32"
        tooltip = Escape-Xml "$($n2.data.name): ~`$$("{0:N1}" -f $n2.data.revenue)B"
    }
    $currOutY1 += $flowH
}

for ($s = 0; $s -lt $sectorData.Count; $s++) {
    $n2 = $col2Nodes[$s]
    $sec = $sectorData[$s]
    foreach ($comp in $compNodeData) {
        $compName = $comp.name
        $k = "$($s):$compName"
        if ($mergedFlows.ContainsKey($k) -and $mergedFlows[$k] -gt 0.1) {
            $val = $mergedFlows[$k]
            $flowH = $val * $scaleY
            $n3 = $col3Nodes[$compName]
            $pathD = Bezier-Ribbon ($xCol2 + $wNode) $n2.curr_out_y ($n2.curr_out_y + $flowH) $xCol3 $n3.curr_in_y ($n3.curr_in_y + $flowH)
            $ribbons += [PSCustomObject]@{
                path = $pathD
                color = $n2.data.color
                opacity = "0.38"
                tooltip = Escape-Xml "$($sec.name) -> $($compName): ~`$$("{0:N1}" -f $val)B"
            }
            $n2.curr_out_y += $flowH
            $n3.curr_in_y += $flowH
        }
    }
}

$totalTStr = "{0:N2}" -f ($totalMarketRev / 1000.0)

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$sb.AppendLine("<svg xmlns=`"http://www.w3.org/2000/svg`" viewBox=`"0 0 $width $height`" width=`"100%`" height=`"100%`" font-family=`"system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif`">")
[void]$sb.AppendLine("  <rect width=`"$width`" height=`"$height`" fill=`"#090d16`" rx=`"14`" />")
[void]$sb.AppendLine("  <text x=`"$marginLeft`" y=`"38`" fill=`"#f8fafc`" font-size=`"22`" font-weight=`"700`">Global Tech Market Flow &amp; Revenue Distribution</text>")
[void]$sb.AppendLine("  <text x=`"$marginLeft`" y=`"58`" fill=`"#94a3b8`" font-size=`"13`">Estimated 2025–2026 Annualized Revenue Breakdown (~`$$totalTStr Trillion Total Market)</text>")
[void]$sb.AppendLine("  <text x=`"$xCol1`" y=`"$($marginTop - 18)`" fill=`"#38bdf8`" font-size=`"12`" font-weight=`"700`" letter-spacing=`"1.2`">GLOBAL MARKET</text>")
[void]$sb.AppendLine("  <text x=`"$xCol2`" y=`"$($marginTop - 18)`" fill=`"#38bdf8`" font-size=`"12`" font-weight=`"700`" letter-spacing=`"1.2`" text-anchor=`"end`">TECH SECTORS</text>")
[void]$sb.AppendLine("  <text x=`"$($xCol3 + $wNode + 12)`" y=`"$($marginTop - 18)`" fill=`"#38bdf8`" font-size=`"12`" font-weight=`"700`" letter-spacing=`"1.2`">MARKET LEADERS &amp; ECOSYSTEMS</text>")

[void]$sb.AppendLine("  <g class=`"ribbons`">")
foreach ($r in $ribbons) {
    [void]$sb.AppendLine("    <path d=`"$($r.path)`" fill=`"$($r.color)`" opacity=`"$($r.opacity)`"><title>$($r.tooltip)</title></path>")
}
[void]$sb.AppendLine("  </g>")

$yCol1_s = "{0:F1}" -f $yCol1Start
$totH_s = "{0:F1}" -f $totalNodeH
$midY1_t = "{0:F1}" -f ($totalNodeH / 2.0 - 7)
$midY1_b = "{0:F1}" -f ($totalNodeH / 2.0 + 9)
[void]$sb.AppendLine("  <g transform=`"translate($xCol1, $yCol1_s)`">")
[void]$sb.AppendLine("    <rect width=`"$wNode`" height=`"$totH_s`" rx=`"4`" fill=`"#38bdf8`" />")
[void]$sb.AppendLine("    <text x=`"$($wNode + 10)`" y=`"$midY1_t`" fill=`"#f8fafc`" font-size=`"12`" font-weight=`"600`">All Sectors</text>")
[void]$sb.AppendLine("    <text x=`"$($wNode + 10)`" y=`"$midY1_b`" fill=`"#94a3b8`" font-size=`"10.5`">~`$$totalTStr`T</text>")
[void]$sb.AppendLine("  </g>")

foreach ($n2 in $col2Nodes) {
    $sec = $n2.data
    $vStr = if ($sec.revenue -ge 1000) { "~`$" + ("{0:N2}" -f ($sec.revenue / 1000.0)) + "T" } elseif ($sec.revenue -lt 10) { "~`$" + ("{0:N1}" -f $sec.revenue) + "B" } else { "~`$" + ("{0:N0}" -f $sec.revenue) + "B" }
    $y2_s = "{0:F1}" -f $n2.y
    $h2_s = "{0:F1}" -f $n2.h
    $midY = $n2.h / 2.0
    $secNameEsc = Escape-Xml $sec.name
    [void]$sb.AppendLine("  <g transform=`"translate($xCol2, $y2_s)`">")
    [void]$sb.AppendLine("    <rect width=`"$wNode`" height=`"$h2_s`" rx=`"3`" fill=`"$($sec.color)`" />")
    if ($n2.h -lt 18) {
        $lblY = "{0:F1}" -f ($midY + 4)
        [void]$sb.AppendLine("    <text x=`"-10`" y=`"$lblY`" text-anchor=`"end`" fill=`"#f8fafc`" font-size=`"12`" font-weight=`"600`">$secNameEsc <tspan fill=`"#94a3b8`" font-size=`"10.5`">($vStr)</tspan></text>")
    } else {
        $lblY_t = "{0:F1}" -f ($midY - 3)
        $lblY_b = "{0:F1}" -f ($midY + 11)
        [void]$sb.AppendLine("    <text x=`"-10`" y=`"$lblY_t`" text-anchor=`"end`" fill=`"#f8fafc`" font-size=`"12`" font-weight=`"600`">$secNameEsc</text>")
        [void]$sb.AppendLine("    <text x=`"-10`" y=`"$lblY_b`" text-anchor=`"end`" fill=`"#94a3b8`" font-size=`"10.5`">$vStr</text>")
    }
    [void]$sb.AppendLine("  </g>")
}

foreach ($comp in $compNodeData) {
    $n3 = $col3Nodes[$comp.name]
    $vStr = if ($comp.value -ge 1000) { "~`$" + ("{0:N2}" -f ($comp.value / 1000.0)) + "T" } elseif ($comp.value -lt 10) { "~`$" + ("{0:N1}" -f $comp.value) + "B" } else { "~`$" + ("{0:N0}" -f $comp.value) + "B" }
    $y3_s = "{0:F1}" -f $n3.y
    $h3_s = "{0:F1}" -f $n3.h
    $midY = $n3.h / 2.0
    $compNameEsc = Escape-Xml $comp.name
    [void]$sb.AppendLine("  <g transform=`"translate($xCol3, $y3_s)`">")
    [void]$sb.AppendLine("    <rect width=`"$wNode`" height=`"$h3_s`" rx=`"3`" fill=`"$($comp.color)`" />")
    if ($n3.h -lt 18) {
        $lblY = "{0:F1}" -f ($midY + 4)
        [void]$sb.AppendLine("    <text x=`"$($wNode + 10)`" y=`"$lblY`" fill=`"#f8fafc`" font-size=`"12`" font-weight=`"600`">$compNameEsc <tspan fill=`"#94a3b8`" font-size=`"10.5`">($vStr)</tspan></text>")
    } else {
        $lblY_t = "{0:F1}" -f ($midY - 2)
        $lblY_b = "{0:F1}" -f ($midY + 11)
        [void]$sb.AppendLine("    <text x=`"$($wNode + 10)`" y=`"$lblY_t`" fill=`"#f8fafc`" font-size=`"12`" font-weight=`"600`">$compNameEsc</text>")
        [void]$sb.AppendLine("    <text x=`"$($wNode + 10)`" y=`"$lblY_b`" fill=`"#94a3b8`" font-size=`"10.5`">$vStr</text>")
    }
    [void]$sb.AppendLine("  </g>")
}

[void]$sb.AppendLine("</svg>")

$OutputFolder = Split-Path -Parent $OutputFile
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

[System.IO.File]::WriteAllText($OutputFile, $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "Successfully generated Sankey Diagram: $(Split-Path -Leaf $OutputFile)!"
