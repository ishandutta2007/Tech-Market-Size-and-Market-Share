#!/usr/bin/env node
/**
 * Generate README.md dynamically from the latest (or specified) market_share_<YEAR>.json data file.
 * Usage:
 *     node scripts/generate_readme.js [--year 2026]
 */

const fs = require('fs');
const path = require('path');

function getLatestDataFile(dataDir, targetYear) {
  if (targetYear) {
    const exactPath = path.join(dataDir, `market_share_${targetYear}.json`);
    if (fs.existsSync(exactPath)) {
      return exactPath;
    }
    throw new Error(`Data file for year ${targetYear} not found: ${exactPath}`);
  }

  const files = fs.readdirSync(dataDir)
    .filter(f => f.startsWith('market_share_') && f.endsWith('.json'))
    .sort();

  if (files.length === 0) {
    throw new Error(`No market_share_<YEAR>.json files found in ${dataDir}`);
  }

  return path.join(dataDir, files[files.length - 1]);
}

function formatLeaders(leaders = [], note) {
  const parts = [];
  if (note) {
    parts.push(`*(${note})*`);
  }

  leaders.forEach((leader, idx) => {
    let entry = `${idx + 1}. **${leader.name}**`;
    if (leader.share) {
      entry += ` (${leader.share})`;
    }
    if (leader.note) {
      entry += ` *(${leader.note})*`;
    }
    parts.push(entry);
  });

  return parts.join('<br>');
}

function renderReadme(data) {
  const year = data.year || '2025–2026';
  const title = data.title || `Market Size and Market Share by Tech Sector (${year} Estimates)`;
  const totalRev = (data.total_revenue || '').replace(/\$/g, '\\$');
  const totalGmv = (data.total_gmv || '').replace(/\$/g, '\\$');
  const sectors = data.sectors || [];
  const highlights = data.highlights || [];

  const rows = sectors.map(sec => {
    let secLabel = `**${sec.name}**`;
    if (sec.subtitle) {
      secLabel += `<br>(${sec.subtitle})`;
    }

    const rev = (sec.revenue || '-').replace(/\$/g, '\\$');
    const gmv = (sec.gmv || '-').replace(/\$/g, '\\$');
    const leadersStr = formatLeaders(sec.leaders, sec.note);

    return `| ${secLabel} | ${rev} | ${gmv} | ${leadersStr} |`;
  });

  const tableRows = rows.join('\n');

  const highlightsStr = highlights.map(h => {
    const icon = h.icon || '💡';
    return `* ${icon} **${h.title}:** ${h.text}`;
  }).join('\n');

  return `<div align="center">
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

### 📊 ${title} 📈

| **Sector** | **Global Market Size (Revenue)** | **Estimated GMV** | **Market Leaders & Competitors (Estimated Mean Share %)** |
| :--- | :--- | :--- | :--- |
${tableRows}
| **Total Estimated Market** | **${totalRev}** | **${totalGmv}** | **Combined major tech sectors listed above** |

---

### 🔎 Market Dynamics Highlights 💡
${highlightsStr}
`;
}

function main() {
  const args = process.argv.slice(2);
  let targetYear = null;
  const yearIdx = args.indexOf('--year');
  if (yearIdx !== -1 && args[yearIdx + 1]) {
    targetYear = args[yearIdx + 1];
  }

  const projectRoot = path.resolve(__dirname, '..');
  const dataDir = path.join(projectRoot, 'data');
  const dataFile = getLatestDataFile(dataDir, targetYear);

  console.log(`Loading data dynamically from: ${path.basename(dataFile)}`);
  const rawData = fs.readFileSync(dataFile, 'utf-8');
  const data = JSON.parse(rawData);

  const readmeContent = renderReadme(data);
  const readmePath = path.join(projectRoot, 'README.md');

  fs.writeFileSync(readmePath, readmeContent, 'utf-8');
  console.log(`Successfully generated ${path.basename(readmePath)} from ${path.basename(dataFile)}!`);
}

main();
