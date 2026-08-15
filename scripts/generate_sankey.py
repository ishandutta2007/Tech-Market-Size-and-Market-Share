#!/usr/bin/env python3
"""
Generate a Sankey Diagram (SVG) for Tech Market Size and Market Share data.
Decoupled, zero-dependency script using pure Python standard library.

Usage:
    python scripts/generate_sankey.py [--year 2026] [--output assets/sankey.svg]
"""

import json
import re
import math
import argparse
from pathlib import Path

def parse_val_to_billions(val_str: str) -> float:
    if not val_str or val_str == "-":
        return 0.0
    clean = val_str.replace("~", "").replace("$", "").replace(",", "").strip()
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
    clean = re.sub(r"[~><%]", "", pct_str).replace("each", "").strip()
    try:
        return float(clean) / 100.0
    except ValueError:
        return 0.0

def bezier_ribbon(x0, y0_top, y0_bot, x1, y1_top, y1_bot) -> str:
    dx = (x1 - x0) * 0.5
    return (
        f"M {x0:.1f} {y0_top:.1f} "
        f"C {x0 + dx:.1f} {y0_top:.1f}, {x1 - dx:.1f} {y1_top:.1f}, {x1:.1f} {y1_top:.1f} "
        f"L {x1:.1f} {y1_bot:.1f} "
        f"C {x1 - dx:.1f} {y1_bot:.1f}, {x0 + dx:.1f} {y0_bot:.1f}, {x0:.1f} {y0_bot:.1f} "
        f"Z"
    )

def generate_sankey_svg(data: dict, width=1200, height=850) -> str:
    sectors = data.get("sectors", [])
    
    # Color palette
    colors = [
        "#3b82f6", "#10b981", "#8b5cf6", "#f59e0b", "#ec4899", 
        "#06b6d4", "#14b8a6", "#f97316", "#6366f1", "#84cc16", 
        "#a855f7", "#eab308", "#64748b"
    ]
    
    # 1. Calculate Sector Values
    sector_data = []
    total_market_rev = 0.0
    for idx, sec in enumerate(sectors):
        rev = parse_val_to_billions(sec.get("revenue"))
        if rev > 0:
            total_market_rev += rev
            sector_data.append({
                "id": sec.get("id", f"sec_{idx}"),
                "name": sec.get("name"),
                "revenue": rev,
                "color": colors[idx % len(colors)],
                "leaders": sec.get("leaders", []),
                "note": sec.get("note")
            })

    # Sort sectors descending by revenue
    sector_data.sort(key=lambda s: s["revenue"], reverse=True)

    # 2. Calculate Company Destinations
    company_totals = {}
    flows_sec_to_comp = [] # (sec_idx, comp_name, value)
    
    for s_idx, sec in enumerate(sector_data):
        accounted_pct = 0.0
        for leader in sec["leaders"]:
            name = leader.get("name")
            # Simplify name for grouping if needed
            clean_name = name.split(" (")[0].strip()
            pct = parse_percent(leader.get("share"))
            flow_val = sec["revenue"] * pct
            accounted_pct += pct
            
            company_totals[clean_name] = company_totals.get(clean_name, 0.0) + flow_val
            flows_sec_to_comp.append({
                "sec_idx": s_idx,
                "comp_name": clean_name,
                "value": flow_val
            })
            
        unaccounted_pct = max(0.0, 1.0 - accounted_pct)
        if unaccounted_pct > 0.01:
            other_val = sec["revenue"] * unaccounted_pct
            other_label = f"Other ({sec['name']})"
            company_totals[other_label] = other_val
            flows_sec_to_comp.append({
                "sec_idx": s_idx,
                "comp_name": other_label,
                "value": other_val
            })

    # Filter top companies and group small ones
    sorted_comps = sorted(company_totals.items(), key=lambda x: x[1], reverse=True)
    top_comps = []
    long_tail_sum = 0.0
    for name, val in sorted_comps:
        if val >= 50.0 and not name.startswith("Other ("):  # Top players >= $50B
            top_comps.append(name)
        else:
            long_tail_sum += val
            
    if long_tail_sum > 0:
        top_comps.append("Other Industry Players")

    # Map flows to top_comps
    remapped_flows = []
    for f in flows_sec_to_comp:
        c_name = f["comp_name"]
        if c_name not in top_comps:
            target = "Other Industry Players"
        else:
            target = c_name
        remapped_flows.append({
            "sec_idx": f["sec_idx"],
            "comp_name": target,
            "value": f["value"]
        })

    # Merge duplicates in remapped_flows
    merged_flows = {}
    for f in remapped_flows:
        key = (f["sec_idx"], f["comp_name"])
        merged_flows[key] = merged_flows.get(key, 0.0) + f["value"]

    # Final list of company node objects
    comp_node_data = []
    for c_idx, c_name in enumerate(top_comps):
        val = sum(merged_flows.get((s_idx, c_name), 0.0) for s_idx in range(len(sector_data)))
        comp_node_data.append({
            "name": c_name,
            "value": val,
            "color": colors[c_idx % len(colors)] if c_name != "Other Industry Players" else "#475569"
        })

    # Geometry Layout
    margin_top = 80
    margin_bottom = 60
    margin_left = 40
    margin_right = 160
    
    usable_h = height - margin_top - margin_bottom
    gap_y = 12
    
    # Scale: height per billion
    total_gaps_col2 = gap_y * (len(sector_data) - 1)
    total_gaps_col3 = gap_y * (len(comp_node_data) - 1)
    
    max_flow_h = usable_h - max(total_gaps_col2, total_gaps_col3)
    scale_y = max_flow_h / total_market_rev

    # Column X Positions
    x_col1 = margin_left
    w_node = 24
    x_col2 = (width - margin_left - margin_right) * 0.44 + margin_left
    x_col3 = width - margin_right

    # 1. Compute Col 1 Node (Total Market)
    total_node_h = total_market_rev * scale_y
    y_col1_start = margin_top + (usable_h - total_node_h) / 2
    
    # 2. Compute Col 2 Nodes (Sectors)
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
        curr_y2 += h + gap_y

    # 3. Compute Col 3 Nodes (Companies)
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
        curr_y3 += h + gap_y

    # Generate Flow Ribbons
    ribbons_1_to_2 = []
    curr_out_y1 = y_col1_start
    for n2 in col2_nodes:
        flow_h = n2["h"]
        path_d = bezier_ribbon(
            x_col1 + w_node, curr_out_y1, curr_out_y1 + flow_h,
            x_col2, n2["y"], n2["y"] + flow_h
        )
        ribbons_1_to_2.append({
            "path": path_d,
            "color": n2["data"]["color"],
            "opacity": 0.35,
            "tooltip": f"{n2['data']['name']}: ~${n2['data']['revenue']:.0f}B"
        })
        curr_out_y1 += flow_h

    ribbons_2_to_3 = []
    for s_idx, sec in enumerate(sector_data):
        n2 = col2_nodes[s_idx]
        for comp_name in top_comps:
            val = merged_flows.get((s_idx, comp_name), 0.0)
            if val > 0.1:
                flow_h = val * scale_y
                n3 = col3_nodes[comp_name]
                
                path_d = bezier_ribbon(
                    x_col2 + w_node, n2["curr_out_y"], n2["curr_out_y"] + flow_h,
                    x_col3, n3["curr_in_y"], n3["curr_in_y"] + flow_h
                )
                ribbons_2_to_3.append({
                    "path": path_d,
                    "color": n2["data"]["color"],
                    "opacity": 0.40,
                    "tooltip": f"{sec['name']} → {comp_name}: ~${val:.1f}B"
                })
                n2["curr_out_y"] += flow_h
                n3["curr_in_y"] += flow_h

    # SVG Construction
    svg_parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="100%" height="100%" style="background:#090d16; border-radius:12px; font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;">',
        '<defs>',
        '  <style>',
        '    .title { fill: #f8fafc; font-size: 20px; font-weight: 700; }',
        '    .subtitle { fill: #94a3b8; font-size: 12px; }',
        '    .node-label { fill: #f1f5f9; font-size: 11.5px; font-weight: 600; }',
        '    .node-sub { fill: #94a3b8; font-size: 10px; }',
        '    .col-header { fill: #38bdf8; font-size: 12px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase; }',
        '    .ribbon { transition: opacity 0.2s ease; }',
        '    .ribbon:hover { opacity: 0.8 !important; }',
        '  </style>',
        '</defs>',
        
        # Header
        f'<text x="{margin_left}" y="36" class="title">Global Tech Market Flow & Revenue Distribution</text>',
        f'<text x="{margin_left}" y="54" class="subtitle">Estimated 2025–2026 Annualized Revenue Breakdown (~${total_market_rev/1000.0:.2f}T Total)</text>',
        
        # Column Headers
        f'<text x="{x_col1}" y="{margin_top - 16}" class="col-header">Total Market</text>',
        f'<text x="{x_col2}" y="{margin_top - 16}" class="col-header">Tech Sectors</text>',
        f'<text x="{x_col3}" y="{margin_top - 16}" class="col-header">Leaders & Ecosystem</text>',
    ]

    # Draw Ribbons
    svg_parts.append('<g class="ribbons">')
    for r in ribbons_1_to_2 + ribbons_2_to_3:
        svg_parts.append(
            f'  <path d="{r["path"]}" fill="{r["color"]}" opacity="{r["opacity"]}" class="ribbon">'
            f'<title>{r["tooltip"]}</title></path>'
        )
    svg_parts.append('</g>')

    # Draw Column 1 Node
    svg_parts.append(
        f'<g transform="translate({x_col1}, {y_col1_start})">'
        f'  <rect width="{w_node}" height="{total_node_h}" rx="4" fill="#38bdf8" />'
        f'  <text x="{w_node + 8}" y="{total_node_h / 2 - 6}" class="node-label">Global Tech Market</text>'
        f'  <text x="{w_node + 8}" y="{total_node_h / 2 + 10}" class="node-sub">~${total_market_rev/1000.0:.2f} Trillion</text>'
        f'</g>'
    )

    # Draw Column 2 Nodes (Sectors)
    for n2 in col2_nodes:
        sec = n2["data"]
        val_str = f"~${sec['revenue']/1000.0:.2f}T" if sec['revenue'] >= 1000 else f"~${sec['revenue']:.0f}B"
        svg_parts.append(
            f'<g transform="translate({x_col2}, {n2["y"]})">'
            f'  <rect width="{w_node}" height="{n2["h"]}" rx="3" fill="{sec["color"]}" />'
            f'  <text x="{w_node + 8}" y="{max(12, min(n2["h"] / 2 - 2, n2["h"] - 14))}" class="node-label">{sec["name"]}</text>'
            f'  <text x="{w_node + 8}" y="{max(24, min(n2["h"] / 2 + 10, n2["h"] - 2))}" class="node-sub">{val_str}</text>'
            f'</g>'
        )

    # Draw Column 3 Nodes (Companies)
    for comp in comp_node_data:
        n3 = col3_nodes[comp["name"]]
        val_str = f"~${comp['value']/1000.0:.2f}T" if comp['value'] >= 1000 else f"~${comp['value']:.0f}B"
        svg_parts.append(
            f'<g transform="translate({x_col3}, {n3["y"]})">'
            f'  <rect width="{w_node}" height="{n3["h"]}" rx="3" fill="{comp["color"]}" />'
            f'  <text x="{w_node + 8}" y="{max(11, min(n3["h"] / 2 - 2, n3["h"] - 12))}" class="node-label">{comp["name"]}</text>'
            f'  <text x="{w_node + 8}" y="{max(22, min(n3["h"] / 2 + 9, n3["h"] - 2))}" class="node-sub">{val_str}</text>'
            f'</g>'
        )

    svg_parts.append('</svg>')
    return '\n'.join(svg_parts)

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
