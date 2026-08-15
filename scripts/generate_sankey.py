#!/usr/bin/env python3
"""
Generate a beautiful, spacious SVG Sankey Diagram for Tech Market Size and Market Share data.
Pure Python standard library (zero external dependencies).
Outputs 100% compliant XML with full entity escaping and zero external CSS reliance.

Usage:
    python scripts/generate_sankey.py [--year 2026] [--output assets/sankey.svg]
"""

import json
import re
import html
import argparse
from pathlib import Path

COMPANY_MAPPINGS = {
    "Microsoft": "Microsoft",
    "Microsoft (Azure)": "Microsoft",
    "Microsoft (Xbox / ABK)": "Microsoft",
    "Microsoft (LinkedIn/Bing)": "Microsoft",
    "Microsoft (Surface)": "Microsoft",
    "Microsoft (Xbox)": "Microsoft",
    "Microsoft (Security)": "Microsoft",
    "Microsoft Azure Quantum": "Microsoft",
    "Google": "Alphabet (Google)",
    "Google (Alphabet)": "Alphabet (Google)",
    "Google (Workspace)": "Alphabet (Google)",
    "Google Cloud": "Alphabet (Google)",
    "Google (Gemini)": "Alphabet (Google)",
    "Google (Play Games)": "Alphabet (Google)",
    "Google Quantum AI": "Alphabet (Google)",
    "Amazon": "Amazon",
    "Amazon (AWS)": "Amazon",
    "Amazon Ads": "Amazon",
    "Amazon Business": "Amazon",
    "Amazon Prime Video": "Amazon",
    "Amazon Robotics": "Amazon",
    "Amazon Braket": "Amazon",
    "Apple": "Apple",
    "Apple (Mac)": "Apple",
    "Apple (App Store Games)": "Apple",
    "Apple (App Store)": "Apple",
    "Apple Ads": "Apple",
    "Apple TV+": "Apple",
    "Meta": "Meta",
    "Meta (Facebook/Instagram)": "Meta",
    "Meta (Facebook)": "Meta",
    "Alibaba": "Alibaba Group",
    "Alibaba (Taobao/Tmall)": "Alibaba Group",
    "Alibaba.com": "Alibaba Group",
    "Alibaba Cloud": "Alibaba Group",
    "Tencent": "Tencent",
    "Tencent Cloud": "Tencent",
    "Tencent Video": "Tencent",
    "Tencent Video / iQIYI": "Tencent",
    "Samsung": "Samsung",
    "Samsung Electronics": "Samsung",
    "Samsung (Memory/LSI)": "Samsung",
    "Samsung (Memory)": "Samsung",
    "Nvidia": "Nvidia",
    "ByteDance": "ByteDance",
    "ByteDance (TikTok/Douyin)": "ByteDance",
    "Douyin E-commerce": "ByteDance",
    "PDD Holdings": "PDD Holdings",
    "PDD Holdings (Temu/Pinduoduo)": "PDD Holdings",
    "JD.com": "JD.com",
    "Cisco": "Cisco",
    "Cisco (Security)": "Cisco",
    "Huawei": "Huawei",
    "Huawei Cloud": "Huawei",
    "Lenovo": "Lenovo",
    "Motorola / Lenovo": "Lenovo",
    "HP Inc.": "HP Inc.",
    "Dell": "Dell",
    "Xiaomi": "Xiaomi",
    "Transsion": "Transsion",
    "Oppo": "Oppo",
    "Vivo": "Vivo",
    "Honor": "Honor",
    "Realme": "Realme",
    "Salesforce": "Salesforce",
    "Intel": "Intel",
    "Intel (Gaudi)": "Intel",
    "Meituan": "Meituan",
    "Netflix": "Netflix",
    "SK Hynix": "SK Hynix",
    "Broadcom": "Broadcom",
    "Broadcom (Custom AI XPUs)": "Broadcom",
    "ASML": "ASML",
    "Qualcomm": "Qualcomm",
    "Sony": "Sony",
    "Sony (PlayStation)": "Sony",
    "Crunchyroll (Sony)": "Sony",
    "Oracle": "Oracle",
    "Oracle Cloud (OCI)": "Oracle",
    "Oracle Cloud": "Oracle",
    "Applied Materials": "Applied Materials",
    "AMD": "AMD",
    "AMD (Instinct)": "AMD",
    "AMD (Client/Embedded)": "AMD",
    "SAP": "SAP",
    "Micron": "Micron",
    "OpenAI": "OpenAI",
    "Lam Research": "Lam Research",
    "Adobe": "Adobe",
    "Arista Networks": "Arista Networks",
    "Palo Alto Networks": "Palo Alto Networks",
    "Tokyo Electron": "Tokyo Electron",
    "Tokyo Electron (TEL)": "Tokyo Electron",
    "Intuit": "Intuit",
    "Nokia": "Nokia",
    "Anthropic": "Anthropic",
    "Ericsson": "Ericsson",
    "CrowdStrike": "CrowdStrike",
    "KLA Corporation": "KLA Corporation",
    "Fortinet": "Fortinet",
    "ServiceNow": "ServiceNow",
    "Workday": "Workday",
    "Shopify": "Shopify",
    "Shopify (Merchant Ecosystem)": "Shopify",
    "Binance": "Binance",
    "Coinbase": "Coinbase",
    "ASUS": "ASUS",
    "Acer": "Acer",
    "MSI": "MSI",
    "Warner Bros (Max)": "Warner Bros. Discovery",
    "Disney+ / Hulu": "Disney",
    "Disney+": "Disney",
    "MediaTek": "MediaTek",
    "Texas Instruments": "Texas Instruments",
    "FANUC": "FANUC",
    "ABB Robotics": "ABB",
    "Intuitive Surgical": "Intuitive Surgical",
    "Midea (KUKA)": "Midea Group (KUKA)",
    "Yaskawa Electric": "Yaskawa Electric",
    "DJI (Enterprise/Industrial)": "DJI",
    "Boston Dynamics / Hyundai": "Hyundai (Boston Dynamics)",
    "AutoStore / Symbotic": "AutoStore / Symbotic",
    "Tesla (Optimus / FSD AI)": "Tesla",
    "Figure AI": "Figure AI",
    "Unitree Robotics": "Unitree Robotics",
    "IBM (IBM Quantum)": "IBM",
    "IBM Cloud": "IBM",
    "Quantinuum (Honeywell)": "Honeywell (Quantinuum)",
    "IonQ": "IonQ",
    "D-Wave Quantum": "D-Wave Quantum",
    "Rigetti Computing": "Rigetti",
    "Juniper Networks / HPE": "HPE (Juniper)",
    "ZTE": "ZTE",
    "Extreme Networks": "Extreme Networks",
    "Ciena": "Ciena",
    "Cloudflare": "Cloudflare",
    "Zscaler": "Zscaler",
    "Check Point": "Check Point",
    "Okta": "Okta",
    "SentinelOne": "SentinelOne",
    "Trend Micro": "Trend Micro",
    "Advantest": "Advantest",
    "Teradyne": "Teradyne",
    "ASM International": "ASM International"
}

def parse_val_to_billions(val_str: str) -> float:
    if not val_str or val_str == "-":
        return 0.0
    clean = str(val_str).replace("~", "").replace("$", "").replace(",", "").strip()
    if "Trillion" in clean:
        num = float(clean.replace("Trillion", "").strip())
        return num * 1000.0
    elif "Billion" in clean:
        num = float(clean.replace("Billion", "").strip())
        return num
    elif "Million" in clean:
        num = float(clean.replace("Million", "").strip())
        return num / 1000.0
    try:
        return float(clean)
    except ValueError:
        return 0.0

def parse_percent(pct_str: str) -> float:
    if not pct_str:
        return 0.0
    clean = re.sub(r"[~><%]", "", str(pct_str)).replace("each", "").replace("GMV", "").strip()
    try:
        return float(clean) / 100.0
    except ValueError:
        return 0.0

# Direct platform corporate revenue distribution for GMV-driven sectors (B2C & B2B e-commerce)
# to avoid conflating ecosystem GMV market shares with direct corporate revenue pools
SECTOR_REVENUE_SHARES = {
    "b2c_ecommerce": {
        "Amazon": 0.190,
        "JD.com": 0.080,
        "Alibaba (Taobao/Tmall)": 0.070,
        "Walmart Online": 0.050,
        "PDD Holdings (Temu/Pinduoduo)": 0.025,
        "Meituan": 0.023,
        "Douyin E-commerce": 0.015,
        "Mercado Libre": 0.010,
        "Shopee (Sea Group)": 0.006,
        "eBay": 0.005,
        "Shopify (Merchant Ecosystem)": 0.000
    },
    "b2b_ecommerce": {
        "W.W. Grainger": 0.032,
        "Amazon Business": 0.020,
        "Alibaba.com": 0.015,
        "Fastenal": 0.015
    }
}

def bezier_ribbon(x0, y0_top, y0_bot, x1, y1_top, y1_bot) -> str:
    dx = (x1 - x0) * 0.48
    return (
        f"M {x0:.1f} {y0_top:.1f} "
        f"C {x0 + dx:.1f} {y0_top:.1f}, {x1 - dx:.1f} {y1_top:.1f}, {x1:.1f} {y1_top:.1f} "
        f"L {x1:.1f} {y1_bot:.1f} "
        f"C {x1 - dx:.1f} {y1_bot:.1f}, {x0 + dx:.1f} {y0_bot:.1f}, {x0:.1f} {y0_bot:.1f} "
        f"Z"
    )

def generate_sankey_svg(data: dict, width=1600, height=2800) -> str:
    sectors = data.get("sectors", [])
    
    palette = [
        "#f97316", "#38bdf8", "#10b981", "#8b5cf6", "#f59e0b", 
        "#ec4899", "#06b6d4", "#6366f1", "#84cc16", "#a855f7", 
        "#eab308", "#14b8a6", "#0ea5e9", "#d946ef", "#64748b",
        "#f43f5e", "#22d3ee", "#e11d48", "#3b82f6", "#10b981"
    ]
    
    # 1. Parse sectors
    sector_data = []
    total_market_rev = 0.0
    for idx, sec in enumerate(sectors):
        rev = parse_val_to_billions(sec.get("revenue"))
        if rev > 0:
            total_market_rev += rev
            sector_data.append({
                "id": sec.get("id", f"sec_{idx}"),
                "name": sec.get("name"),
                "subtitle": sec.get("subtitle", ""),
                "revenue": rev,
                "color": palette[idx % len(palette)],
                "leaders": sec.get("leaders", []),
                "note": sec.get("note")
            })

    # Sort sectors descending by revenue
    sector_data.sort(key=lambda s: s["revenue"], reverse=True)

    # 2. Map flows to unified companies
    company_totals = {}
    flows_sec_to_comp = []
    
    for s_idx, sec in enumerate(sector_data):
        sec_id = sec.get("id")
        accounted_pct = 0.0
        for leader in sec["leaders"]:
            raw_name = leader.get("name")
            mapped_name = COMPANY_MAPPINGS.get(raw_name, raw_name.split(" (")[0].strip())
            
            if "revenue_share" in leader:
                pct = parse_percent(leader.get("revenue_share"))
            elif sec_id in SECTOR_REVENUE_SHARES and raw_name in SECTOR_REVENUE_SHARES[sec_id]:
                pct = SECTOR_REVENUE_SHARES[sec_id][raw_name]
            else:
                pct = parse_percent(leader.get("share"))
                
            flow_val = sec["revenue"] * pct
            accounted_pct += pct
            
            if flow_val > 0:
                company_totals[mapped_name] = company_totals.get(mapped_name, 0.0) + flow_val
                flows_sec_to_comp.append({
                    "sec_idx": s_idx,
                    "comp_name": mapped_name,
                    "value": flow_val
                })
            
        unaccounted_pct = max(0.0, 1.0 - accounted_pct)
        if unaccounted_pct > 0.005:
            other_val = sec["revenue"] * unaccounted_pct
            other_label = "Other Industry Players"
            company_totals[other_label] = company_totals.get(other_label, 0.0) + other_val
            flows_sec_to_comp.append({
                "sec_idx": s_idx,
                "comp_name": other_label,
                "value": other_val
            })

    # Filter top companies with revenue threshold >= $14.5B to capture all major tech leaders
    # (including Cisco, Qualcomm, SAP, Oracle, SK Hynix, Micron, Anthropic, OpenAI, ASML, Broadcom, etc.)
    sorted_comps = sorted(company_totals.items(), key=lambda x: x[1], reverse=True)
    top_comps = []
    other_acc = 0.0
    MIN_THRESHOLD = 14.5
    for name, val in sorted_comps:
        if name == "Other Industry Players":
            other_acc += val
        elif val >= MIN_THRESHOLD:
            top_comps.append(name)
        else:
            other_acc += val

    # Append aggregated Other Industry Players
    if other_acc > 0:
        top_comps.append("Other Industry Players")

    # Map flows
    merged_flows = {}
    for f in flows_sec_to_comp:
        target = f["comp_name"] if f["comp_name"] in top_comps else "Other Industry Players"
        key = (f["sec_idx"], target)
        merged_flows[key] = merged_flows.get(key, 0.0) + f["value"]

    # Final company node objects
    comp_node_data = []
    comp_colors = [
        "#f97316", "#38bdf8", "#8b5cf6", "#10b981", "#f59e0b",
        "#ec4899", "#06b6d4", "#a855f7", "#84cc16", "#6366f1",
        "#eab308", "#14b8a6", "#f43f5e", "#22d3ee", "#e11d48",
        "#10b981", "#3b82f6", "#f97316", "#8b5cf6", "#0ea5e9",
        "#14b8a6", "#f59e0b", "#ec4899", "#a855f7", "#84cc16",
        "#6366f1", "#eab308", "#38bdf8", "#f43f5e", "#22d3ee"
    ]
    for c_idx, c_name in enumerate(top_comps):
        val = sum(merged_flows.get((s_idx, c_name), 0.0) for s_idx in range(len(sector_data)))
        col = "#475569" if c_name == "Other Industry Players" else comp_colors[c_idx % len(comp_colors)]
        comp_node_data.append({
            "name": c_name,
            "value": val,
            "color": col
        })

    # Layout coordinates - spacious, doubled-height styling
    margin_top = 110
    margin_bottom = 60
    margin_left = 36
    margin_right = 320
    
    usable_h = height - margin_top - margin_bottom
    gap_y_sec = 18
    gap_y_comp = 14
    
    total_gaps_col2 = gap_y_sec * (len(sector_data) - 1)
    total_gaps_col3 = gap_y_comp * (len(comp_node_data) - 1)
    
    max_flow_h = usable_h - max(total_gaps_col2, total_gaps_col3)
    scale_y = max_flow_h / total_market_rev

    # Node positions
    w_node = 22
    x_col1 = margin_left
    x_col2 = 600
    x_col3 = width - margin_right

    # 1. Total Market Node (Col 1)
    total_node_h = total_market_rev * scale_y
    y_col1_start = margin_top + (usable_h - total_node_h) / 2.0

    # 2. Sector Nodes (Col 2)
    col2_nodes = []
    curr_y2 = margin_top
    for sec in sector_data:
        h = sec["revenue"] * scale_y
        col2_nodes.append({
            "y": curr_y2,
            "h": h,
            "data": sec,
            "curr_out_y": curr_y2,
            "curr_in_y": curr_y2
        })
        curr_y2 += h + gap_y_sec

    # 3. Company Nodes (Col 3)
    col3_nodes = {}
    curr_y3 = margin_top
    for comp in comp_node_data:
        h = comp["value"] * scale_y
        col3_nodes[comp["name"]] = {
            "y": curr_y3,
            "h": h,
            "data": comp,
            "curr_in_y": curr_y3
        }
        curr_y3 += h + gap_y_comp

    # Build ribbons
    ribbons = []
    
    # Col 1 -> Col 2
    curr_out_y1 = y_col1_start
    for n2 in col2_nodes:
        flow_h = n2["h"]
        path_d = bezier_ribbon(
            x_col1 + w_node, curr_out_y1, curr_out_y1 + flow_h,
            x_col2, n2["y"], n2["y"] + flow_h
        )
        ribbons.append({
            "path": path_d,
            "color": n2["data"]["color"],
            "opacity": "0.32",
            "tooltip": html.escape(f"{n2['data']['name']}: ~${n2['data']['revenue']:.1f}B")
        })
        curr_out_y1 += flow_h

    # Col 2 -> Col 3
    for s_idx, sec in enumerate(sector_data):
        n2 = col2_nodes[s_idx]
        for comp in comp_node_data:
            c_name = comp["name"]
            val = merged_flows.get((s_idx, c_name), 0.0)
            if val > 0.1:
                flow_h = val * scale_y
                n3 = col3_nodes[c_name]
                path_d = bezier_ribbon(
                    x_col2 + w_node, n2["curr_out_y"], n2["curr_out_y"] + flow_h,
                    x_col3, n3["curr_in_y"], n3["curr_in_y"] + flow_h
                )
                ribbons.append({
                    "path": path_d,
                    "color": n2["data"]["color"],
                    "opacity": "0.38",
                    "tooltip": html.escape(f"{sec['name']} → {c_name}: ~${val:.1f}B")
                })
                n2["curr_out_y"] += flow_h
                n3["curr_in_y"] += flow_h

    # Build pure XML SVG
    svg = []
    svg.append('<?xml version="1.0" encoding="UTF-8"?>')
    svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="100%" height="100%" font-family="system-ui, -apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, sans-serif">')
    
    # Background rect
    svg.append(f'  <rect width="{width}" height="{height}" fill="#090d16" rx="16" />')
    
    # Header text
    svg.append(f'  <text x="{margin_left}" y="44" fill="#f8fafc" font-size="26" font-weight="700">Global Tech Market Flow &amp; Revenue Distribution</text>')
    svg.append(f'  <text x="{margin_left}" y="70" fill="#94a3b8" font-size="14">Estimated 2025–2026 Annualized Revenue Breakdown (~${total_market_rev/1000.0:.2f} Trillion Total Market)</text>')

    # Column Headers
    svg.append(f'  <text x="{x_col1}" y="{margin_top - 18}" fill="#38bdf8" font-size="13" font-weight="700" letter-spacing="1.5">GLOBAL MARKET</text>')
    svg.append(f'  <text x="{x_col2}" y="{margin_top - 18}" fill="#38bdf8" font-size="13" font-weight="700" letter-spacing="1.5" text-anchor="end">TECH SECTORS</text>')
    svg.append(f'  <text x="{x_col3 + w_node + 14}" y="{margin_top - 18}" fill="#38bdf8" font-size="13" font-weight="700" letter-spacing="1.5">MARKET LEADERS &amp; ECOSYSTEMS</text>')

    # Ribbons
    svg.append('  <g class="ribbons">')
    for r in ribbons:
        svg.append(f'    <path d="{r["path"]}" fill="{r["color"]}" opacity="{r["opacity"]}"><title>{r["tooltip"]}</title></path>')
    svg.append('  </g>')

    # Col 1: Total Market Node
    svg.append(f'  <g transform="translate({x_col1}, {y_col1_start:.1f})">')
    svg.append(f'    <rect width="{w_node}" height="{total_node_h:.1f}" rx="5" fill="#38bdf8" />')
    svg.append(f'    <text x="{w_node + 12}" y="{total_node_h / 2.0 - 8:.1f}" fill="#f8fafc" font-size="14" font-weight="600">All Sectors</text>')
    svg.append(f'    <text x="{w_node + 12}" y="{total_node_h / 2.0 + 12:.1f}" fill="#94a3b8" font-size="12">~${total_market_rev/1000.0:.2f}T</text>')
    svg.append('  </g>')

    # Col 2: Sectors (Labels placed to the left of the node at text-anchor="end")
    for n2 in col2_nodes:
        sec = n2["data"]
        val_str = f"~${sec['revenue']/1000.0:.2f}T" if sec['revenue'] >= 1000 else (f"~${sec['revenue']:.1f}B" if sec['revenue'] < 10 else f"~${sec['revenue']:.0f}B")
        mid_y = n2["h"] / 2.0
        sec_name_esc = html.escape(sec["name"])
        svg.append(f'  <g transform="translate({x_col2}, {n2["y"]:.1f})">')
        svg.append(f'    <rect width="{w_node}" height="{n2["h"]:.1f}" rx="4" fill="{sec["color"]}" />')
        
        if n2["h"] < 22:
            svg.append(f'    <text x="-12" y="{mid_y + 4.5:.1f}" text-anchor="end" fill="#f8fafc" font-size="12.5" font-weight="600">{sec_name_esc} <tspan fill="#94a3b8" font-size="11">({val_str})</tspan></text>')
        else:
            svg.append(f'    <text x="-12" y="{mid_y - 3:.1f}" text-anchor="end" fill="#f8fafc" font-size="12.5" font-weight="600">{sec_name_esc}</text>')
            svg.append(f'    <text x="-12" y="{mid_y + 12:.1f}" text-anchor="end" fill="#94a3b8" font-size="11">{val_str}</text>')
        svg.append('  </g>')

    # Col 3: Companies (Labels placed to the right of node at text-anchor="start")
    for comp in comp_node_data:
        n3 = col3_nodes[comp["name"]]
        val_str = f"~${comp['value']/1000.0:.2f}T" if comp['value'] >= 1000 else f"~${comp['value']:.0f}B"
        mid_y = n3["h"] / 2.0
        comp_name_esc = html.escape(comp["name"])
        svg.append(f'  <g transform="translate({x_col3}, {n3["y"]:.1f})">')
        svg.append(f'    <rect width="{w_node}" height="{n3["h"]:.1f}" rx="4" fill="{comp["color"]}" />')
        
        if n3["h"] < 22:
            svg.append(f'    <text x="{w_node + 12}" y="{mid_y + 4.5:.1f}" fill="#f8fafc" font-size="12.5" font-weight="600">{comp_name_esc} <tspan fill="#94a3b8" font-size="11">({val_str})</tspan></text>')
        else:
            svg.append(f'    <text x="{w_node + 12}" y="{mid_y - 3:.1f}" fill="#f8fafc" font-size="12.5" font-weight="600">{comp_name_esc}</text>')
            svg.append(f'    <text x="{w_node + 12}" y="{mid_y + 12:.1f}" fill="#94a3b8" font-size="11">{val_str}</text>')
        svg.append('  </g>')

    svg.append('</svg>')
    return '\n'.join(svg)

def main():
    parser = argparse.ArgumentParser(description="Generate pure SVG Sankey Diagram from data.")
    parser.add_argument("--year", type=str, default="2026", help="Year suffix of dataset")
    parser.add_argument("--output", type=str, default="assets/sankey.svg", help="Output path for SVG")
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent
    data_file = project_root / "data" / f"market_share_{args.year}.json"
    out_file = project_root / args.output

    out_file.parent.mkdir(parents=True, exist_ok=True)

    print(f"Reading dataset: {data_file.name}")
    with open(data_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    svg_content = generate_sankey_svg(data)
    with open(out_file, "w", encoding="utf-8") as f:
        f.write(svg_content)

    print(f"Successfully generated Sankey Diagram: {out_file}!")

if __name__ == "__main__":
    main()
