#!/usr/bin/env python3
"""
Generate README.md dynamically from the latest (or specified) market_share_<YEAR>.json data file.
Usage:
    python scripts/generate_readme.py [--year 2026]
"""

import json
import os
import glob
import argparse
from pathlib import Path

def find_latest_data_file(data_dir: Path, target_year: str = None) -> Path:
    if target_year:
        exact_path = data_dir / f"market_share_{target_year}.json"
        if exact_path.exists():
            return exact_path
        raise FileNotFoundError(f"Data file for year {target_year} not found: {exact_path}")
    
    files = sorted(glob.glob(str(data_dir / "market_share_*.json")))
    if not files:
        raise FileNotFoundError(f"No market_share_<YEAR>.json files found in {data_dir}")
    return Path(files[-1])

def format_leaders(leaders, note=None) -> str:
    parts = []
    if note:
        parts.append(f"*({note})*")
    
    for idx, leader in enumerate(leaders, 1):
        name = leader.get("name")
        share = leader.get("share")
        leader_note = leader.get("note")
        
        entry = f"{idx}. **{name}**"
        if share:
            entry += f" ({share})"
        if leader_note:
            entry += f" *({leader_note})*"
        parts.append(entry)
    
    return "<br>".join(parts)

def render_readme(data: dict) -> str:
    year = data.get("year", "2025–2026")
    title = data.get("title", f"Market Size and Market Share by Tech Sector ({year} Estimates)")
    total_rev = data.get("total_revenue", "")
    total_gmv = data.get("total_gmv", "")
    sectors = data.get("sectors", [])
    highlights = data.get("highlights", [])

    rows = []
    for sec in sectors:
        name = sec.get("name")
        sub = sec.get("subtitle", "")
        sec_label = f"**{name}**"
        if sub:
            sec_label += f"<br>({sub})"
        
        rev = sec.get("revenue", "-").replace("$", "\\$")
        gmv = sec.get("gmv", "-").replace("$", "\\$")
        leaders_str = format_leaders(sec.get("leaders", []), sec.get("note"))
        
        rows.append(f"| {sec_label} | {rev} | {gmv} | {leaders_str} |")

    table_rows = "\n".join(rows)
    total_rev_esc = total_rev.replace("$", "\\$")
    total_gmv_esc = total_gmv.replace("$", "\\$")

    highlights_list = []
    for h in highlights:
        icon = h.get("icon", "💡")
        h_title = h.get("title", "")
        h_text = h.get("text", "")
        highlights_list.append(f"* {icon} **{h_title}:** {h_text}")

    highlights_str = "\n".join(highlights_list)

    markdown = f"""<div align="center">
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

### 📊 {title} 📈

| **Sector** | **Global Market Size (Revenue)** | **Estimated GMV** | **Market Leaders & Competitors (Estimated Mean Share %)** |
| :--- | :--- | :--- | :--- |
{table_rows}
| **Total Estimated Market** | **{total_rev_esc}** | **{total_gmv_esc}** | **Combined major tech sectors listed above** |

---

### 🔎 Market Dynamics Highlights 💡
{highlights_str}
"""
    return markdown

def main():
    parser = argparse.ArgumentParser(description="Generate README.md dynamically from data JSON.")
    parser.add_argument("--year", type=str, default=None, help="Year suffix of the dataset (e.g., 2026)")
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent
    data_dir = project_root / "data"
    data_file = find_latest_data_file(data_dir, args.year)

    print(f"Loading data dynamically from: {data_file.name}")
    with open(data_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    readme_content = render_readme(data)
    readme_path = project_root / "README.md"
    
    with open(readme_path, "w", encoding="utf-8") as f:
        f.write(readme_content)

    print(f"Successfully generated {readme_path.name} from {data_file.name}!")

if __name__ == "__main__":
    main()
