param (
    [string]$Year = "2026",
    [string]$Output = "assets/sankey.svg"
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$DataFile = Join-Path $ProjectRoot "data\market_share_$Year.json"
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
    "Microsoft (Security)" = "Microsoft";
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
    "Cisco" = "Cisco";
    "Cisco (Security)" = "Cisco";
    "Huawei" = "Huawei";
    "Huawei Cloud" = "Huawei";
    "Lenovo" = "Lenovo";
    "Motorola / Lenovo" = "Lenovo";
    "HP Inc." = "HP Inc.";
    "Dell" = "Dell";
    "Xiaomi" = "Xiaomi";
    "Transsion" = "Transsion";
    "Oppo" = "Oppo";
    "Vivo" = "Vivo";
    "Honor" = "Honor";
    "Realme" = "Realme";
    "Salesforce" = "Salesforce";
    "Intel" = "Intel";
    "Intel (Gaudi)" = "Intel";
    "Meituan" = "Meituan";
    "Netflix" = "Netflix";
    "SK Hynix" = "SK Hynix";
    "Broadcom" = "Broadcom";
    "Broadcom (Custom AI XPUs)" = "Broadcom";
    "ASML" = "ASML";
    "Qualcomm" = "Qualcomm";
    "Sony" = "Sony";
    "Sony (PlayStation)" = "Sony";
    "Crunchyroll (Sony)" = "Sony";
    "Oracle" = "Oracle";
    "Oracle Cloud (OCI)" = "Oracle";
    "Oracle Cloud" = "Oracle";
    "Applied Materials" = "Applied Materials";
    "AMD" = "AMD";
    "AMD (Instinct)" = "AMD";
    "AMD (Client/Embedded)" = "AMD";
    "SAP" = "SAP";
    "Micron" = "Micron";
    "OpenAI" = "OpenAI";
    "Lam Research" = "Lam Research";
    "Adobe" = "Adobe";
    "Arista Networks" = "Arista Networks";
    "Palo Alto Networks" = "Palo Alto Networks";
    "Tokyo Electron" = "Tokyo Electron";
    "Tokyo Electron (TEL)" = "Tokyo Electron";
    "Intuit" = "Intuit";
    "Nokia" = "Nokia";
    "Anthropic" = "Anthropic";
    "Ericsson" = "Ericsson";
    "CrowdStrike" = "CrowdStrike";
    "KLA Corporation" = "KLA Corporation";
    "Fortinet" = "Fortinet";
    "ServiceNow" = "ServiceNow";
    "Workday" = "Workday";
    "Shopify" = "Shopify";
    "Shopify (Merchant Ecosystem)" = "Shopify";
    "Binance" = "Binance";
    "Coinbase" = "Coinbase";
    "ASUS" = "ASUS";
    "Acer" = "Acer";
    "MSI" = "MSI";
    "Warner Bros (Max)" = "Warner Bros. Discovery";
    "Disney+ / Hulu" = "Disney";
    "Disney+" = "Disney";
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
    "Rigetti Computing" = "Rigetti";
    "Juniper Networks / HPE" = "HPE (Juniper)";
    "ZTE" = "ZTE";
    "Extreme Networks" = "Extreme Networks";
    "Ciena" = "Ciena";
    "Cloudflare" = "Cloudflare";
    "Zscaler" = "Zscaler";
    "Check Point" = "Check Point";
    "Okta" = "Okta";
    "SentinelOne" = "SentinelOne";
    "Trend Micro" = "Trend Micro";
    "Advantest" = "Advantest";
    "Teradyne" = "Teradyne";
    "ASM International" = "ASM International"
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
    $clean = "$pctStr" -replace '[~><%]', '' -replace 'each', '' -replace 'GMV', ''
    $clean = $clean.Trim()
    try { return [double]$clean / 100.0 } catch { return 0.0 }
}

$SectorRevenueShares = @{
    "b2c_ecommerce" = @{
        "Amazon" = 0.190;
        "JD.com" = 0.080;
        "Alibaba (Taobao/Tmall)" = 0.070;
        "Walmart Online" = 0.050;
        "PDD Holdings (Temu/Pinduoduo)" = 0.025;
        "Meituan" = 0.023;
        "Douyin E-commerce" = 0.015;
        "Mercado Libre" = 0.010;
        "Shopee (Sea Group)" = 0.006;
        "eBay" = 0.005;
        "Shopify (Merchant Ecosystem)" = 0.000;
    };
    "b2b_ecommerce" = @{
        "W.W. Grainger" = 0.032;
        "Amazon Business" = 0.020;
        "Alibaba.com" = 0.015;
        "Fastenal" = 0.015;
    }
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

$palette = @(
    "#f97316", "#38bdf8", "#10b981", "#8b5cf6", "#f59e0b",
    "#ec4899", "#06b6d4", "#6366f1", "#84cc16", "#a855f7",
    "#eab308", "#14b8a6", "#0ea5e9", "#d946ef", "#64748b",
    "#f43f5e", "#22d3ee", "#e11d48", "#3b82f6", "#10b981"
)

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
    $secId = $sec.id
    $accountedPct = 0.0
    foreach ($leader in $sec.leaders) {
        $rawName = $leader.name
        $mappedName = if ($CompanyMappings.ContainsKey($rawName)) { $CompanyMappings[$rawName] } else { ($rawName -split ' \(')[0].Trim() }
        
        $pct = if ($leader.revenue_share) {
            Parse-Pct $leader.revenue_share
        } elseif ($SectorRevenueShares.ContainsKey($secId) -and $SectorRevenueShares[$secId].ContainsKey($rawName)) {
            $SectorRevenueShares[$secId][$rawName]
        } else {
            Parse-Pct $leader.share
        }
        
        $flowVal = $sec.revenue * $pct
        $accountedPct += $pct

        if ($flowVal -gt 0) {
            if (-not $companyTotals.ContainsKey($mappedName)) { $companyTotals[$mappedName] = 0.0 }
            $companyTotals[$mappedName] += $flowVal

            $flowsSecToComp += [PSCustomObject]@{
                sec_idx = $s_idx
                comp_name = $mappedName
                value = $flowVal
            }
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

$sortedComps = $companyTotals.GetEnumerator() | Sort-Object -Property Value -Descending
$topComps = @()
$otherAcc = 0.0
$MIN_THRESHOLD = 14.5

foreach ($kv in $sortedComps) {
    $name = $kv.Key
    $val = $kv.Value
    if ($name -eq "Other Industry Players") {
        $otherAcc += $val
    } elseif ($val -ge $MIN_THRESHOLD) {
        $topComps += $name
    } else {
        $otherAcc += $val
    }
}

if ($otherAcc -gt 0) {
    $topComps += "Other Industry Players"
}

$mergedFlows = @{}
foreach ($f in $flowsSecToComp) {
    $target = if ($topComps -contains $f.comp_name) { $f.comp_name } else { "Other Industry Players" }
    $key = "$($f.sec_idx)|$target"
    if (-not $mergedFlows.ContainsKey($key)) { $mergedFlows[$key] = 0.0 }
    $mergedFlows[$key] += $f.value
}

$compColors = @(
    "#f97316", "#38bdf8", "#8b5cf6", "#10b981", "#f59e0b",
    "#ec4899", "#06b6d4", "#a855f7", "#84cc16", "#6366f1",
    "#eab308", "#14b8a6", "#f43f5e", "#22d3ee", "#e11d48",
    "#10b981", "#3b82f6", "#f97316", "#8b5cf6", "#0ea5e9",
    "#14b8a6", "#f59e0b", "#ec4899", "#a855f7", "#84cc16",
    "#6366f1", "#eab308", "#38bdf8", "#f43f5e", "#22d3ee"
)

$compNodeData = @()
$c_idx = 0
foreach ($cName in $topComps) {
    $cVal = 0.0
    for ($s = 0; $s -lt $sectorData.Count; $s++) {
        $k = "$s|$cName"
        if ($mergedFlows.ContainsKey($k)) {
            $cVal += $mergedFlows[$k]
        }
    }
    $col = if ($cName -eq "Other Industry Players") { "#475569" } else { $compColors[$c_idx % $compColors.Count] }
    $compNodeData += [PSCustomObject]@{
        name = $cName
        value = $cVal
        color = $col
    }
    $c_idx++
}

$width = 1600
$height = 2800
$marginTop = 110
$marginBottom = 60
$marginLeft = 36
$marginRight = 320

$usableH = $height - $marginTop - $marginBottom
$gapYSec = 18
$gapYComp = 14

$totalGapsCol2 = $gapYSec * ($sectorData.Count - 1)
$totalGapsCol3 = $gapYComp * ($compNodeData.Count - 1)

$maxFlowH = $usableH - [Math]::Max($totalGapsCol2, $totalGapsCol3)
$scaleY = $maxFlowH / $totalMarketRev

$wNode = 22
$xCol1 = $marginLeft
$xCol2 = 600
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
        curr_in_y = $currY2
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
    $secRevStr = if ($n2.data.revenue -ge 1000) { "{0:N2}T" -f ($n2.data.revenue / 1000.0) } else { "{0:N1}B" -f $n2.data.revenue }
    $ribbons += [PSCustomObject]@{
        path = $pathD
        color = $n2.data.color
        opacity = "0.32"
        tooltip = Escape-Xml "$($n2.data.name): ~`$$secRevStr"
    }
    $currOutY1 += $flowH
}

for ($s_i = 0; $s_i -lt $sectorData.Count; $s_i++) {
    $sec = $sectorData[$s_i]
    $n2 = $col2Nodes[$s_i]
    foreach ($comp in $compNodeData) {
        $compName = $comp.name
        $k = "$s_i|$compName"
        $val = if ($mergedFlows.ContainsKey($k)) { $mergedFlows[$k] } else { 0.0 }
        if ($val -gt 0.1) {
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
[void]$sb.AppendLine("<svg xmlns=`"http://www.w3.org/2000/svg`" viewBox=`"0 0 $width $height`" width=`"$width`" height=`"$height`" font-family=`"system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif`">")
[void]$sb.AppendLine("  <rect width=`"$width`" height=`"$height`" fill=`"#090d16`" rx=`"16`" />")
[void]$sb.AppendLine("  <text x=`"$marginLeft`" y=`"44`" fill=`"#f8fafc`" font-size=`"26`" font-weight=`"700`">Global Tech Market Flow &amp; Revenue Distribution</text>")
[void]$sb.AppendLine("  <text x=`"$marginLeft`" y=`"70`" fill=`"#94a3b8`" font-size=`"14`">Estimated 2025-2026 Annualized Revenue Breakdown (~`$$totalTStr Trillion Total Market)</text>")
[void]$sb.AppendLine("  <text x=`"$xCol1`" y=`"$($marginTop - 18)`" fill=`"#38bdf8`" font-size=`"13`" font-weight=`"700`" letter-spacing=`"1.5`">GLOBAL MARKET</text>")
[void]$sb.AppendLine("  <text x=`"$xCol2`" y=`"$($marginTop - 18)`" fill=`"#38bdf8`" font-size=`"13`" font-weight=`"700`" letter-spacing=`"1.5`" text-anchor=`"end`">TECH SECTORS</text>")
[void]$sb.AppendLine("  <text x=`"$($xCol3 + $wNode + 14)`" y=`"$($marginTop - 18)`" fill=`"#38bdf8`" font-size=`"13`" font-weight=`"700`" letter-spacing=`"1.5`">MARKET LEADERS &amp; ECOSYSTEMS</text>")

[void]$sb.AppendLine("  <g class=`"ribbons`">")
foreach ($r in $ribbons) {
    [void]$sb.AppendLine("    <path d=`"$($r.path)`" fill=`"$($r.color)`" opacity=`"$($r.opacity)`"><title>$($r.tooltip)</title></path>")
}
[void]$sb.AppendLine("  </g>")

$yCol1_s = "{0:F1}" -f $yCol1Start
$totH_s = "{0:F1}" -f $totalNodeH
$midY1_t = "{0:F1}" -f ($totalNodeH / 2.0 - 8)
$midY1_b = "{0:F1}" -f ($totalNodeH / 2.0 + 12)
[void]$sb.AppendLine("  <g transform=`"translate($xCol1, $yCol1_s)`">")
[void]$sb.AppendLine("    <rect width=`"$wNode`" height=`"$totH_s`" rx=`"5`" fill=`"#38bdf8`" />")
[void]$sb.AppendLine("    <text x=`"$($wNode + 12)`" y=`"$midY1_t`" fill=`"#f8fafc`" font-size=`"14`" font-weight=`"600`">All Sectors</text>")
[void]$sb.AppendLine("    <text x=`"$($wNode + 12)`" y=`"$midY1_b`" fill=`"#94a3b8`" font-size=`"12`">~`$$totalTStr`T</text>")
[void]$sb.AppendLine("  </g>")

foreach ($n2 in $col2Nodes) {
    $sec = $n2.data
    $vStr = if ($sec.revenue -ge 1000) { "~`$" + ("{0:N2}" -f ($sec.revenue / 1000.0)) + "T" } elseif ($sec.revenue -lt 10) { "~`$" + ("{0:N1}" -f $sec.revenue) + "B" } else { "~`$" + ("{0:N0}" -f $sec.revenue) + "B" }
    $y2_s = "{0:F1}" -f $n2.y
    $h2_s = "{0:F1}" -f $n2.h
    $midY = $n2.h / 2.0
    $secNameEsc = Escape-Xml $sec.name
    [void]$sb.AppendLine("  <g transform=`"translate($xCol2, $y2_s)`">")
    [void]$sb.AppendLine("    <rect width=`"$wNode`" height=`"$h2_s`" rx=`"4`" fill=`"$($sec.color)`" />")
    if ($n2.h -lt 22) {
        $lblY = "{0:F1}" -f ($midY + 4.5)
        [void]$sb.AppendLine("    <text x=`"-12`" y=`"$lblY`" text-anchor=`"end`" fill=`"#f8fafc`" font-size=`"12.5`" font-weight=`"600`">$secNameEsc <tspan fill=`"#94a3b8`" font-size=`"11`">($vStr)</tspan></text>")
    } else {
        $lblY1 = "{0:F1}" -f ($midY - 3)
        $lblY2 = "{0:F1}" -f ($midY + 12)
        [void]$sb.AppendLine("    <text x=`"-12`" y=`"$lblY1`" text-anchor=`"end`" fill=`"#f8fafc`" font-size=`"12.5`" font-weight=`"600`">$secNameEsc</text>")
        [void]$sb.AppendLine("    <text x=`"-12`" y=`"$lblY2`" text-anchor=`"end`" fill=`"#94a3b8`" font-size=`"11`">$vStr</text>")
    }
    [void]$sb.AppendLine("  </g>")
}

foreach ($comp in $compNodeData) {
    $n3 = $col3Nodes[$comp.name]
    $vStr = if ($comp.value -ge 1000) { "~`$" + ("{0:N2}" -f ($comp.value / 1000.0)) + "T" } else { "~`$" + ("{0:N0}" -f $comp.value) + "B" }
    $y3_s = "{0:F1}" -f $n3.y
    $h3_s = "{0:F1}" -f $n3.h
    $midY = $n3.h / 2.0
    $compNameEsc = Escape-Xml $comp.name
    [void]$sb.AppendLine("  <g transform=`"translate($xCol3, $y3_s)`">")
    [void]$sb.AppendLine("    <rect width=`"$wNode`" height=`"$h3_s`" rx=`"4`" fill=`"$($comp.color)`" />")
    if ($n3.h -lt 22) {
        $lblY = "{0:F1}" -f ($midY + 4.5)
        [void]$sb.AppendLine("    <text x=`"$($wNode + 12)`" y=`"$lblY`" fill=`"#f8fafc`" font-size=`"12.5`" font-weight=`"600`">$compNameEsc <tspan fill=`"#94a3b8`" font-size=`"11`">($vStr)</tspan></text>")
    } else {
        $lblY1 = "{0:F1}" -f ($midY - 3)
        $lblY2 = "{0:F1}" -f ($midY + 12)
        [void]$sb.AppendLine("    <text x=`"$($wNode + 12)`" y=`"$lblY1`" fill=`"#f8fafc`" font-size=`"12.5`" font-weight=`"600`">$compNameEsc</text>")
        [void]$sb.AppendLine("    <text x=`"$($wNode + 12)`" y=`"$lblY2`" fill=`"#94a3b8`" font-size=`"11`">$vStr</text>")
    }
    [void]$sb.AppendLine("  </g>")
}

[void]$sb.AppendLine("</svg>")

$OutDir = Split-Path -Parent $OutputFile
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutputFile, $sb.ToString(), $utf8NoBom)
Write-Host "Successfully generated Sankey Diagram: $OutputFile!"
