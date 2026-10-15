/**
 * 报告生成器：本地 HTML 分析报告（内嵌 SVG 现金流图，可直接打印/转 PDF）
 */
import { Plan } from '../model/PlanV2';
import { simulate, SimResult } from './SimEngine';

function esc(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function yuan(v: number): string {
  return v.toFixed(2);
}

function cashFlowSvg(r: SimResult): string {
  const w = 720;
  const h = 240;
  const padL = 60;
  const padR = 20;
  const padT = 20;
  const padB = 30;
  const plotW = w - padL - padR;
  const plotH = h - padT - padB;
  let maxV = 0;
  let minV = 0;
  for (const v of r.cashFlow) {
    if (v > maxV) {
      maxV = v;
    }
    if (v < minV) {
      minV = v;
    }
  }
  if (maxV === minV) {
    maxV = minV + 1;
  }
  const range = maxV - minV;
  const yOf = (v: number): number => padT + plotH * (1 - (v - minV) / range);
  let grid = '';
  for (let g = 0; g <= 4; g++) {
    const v = minV + range * g / 4;
    const y = yOf(v).toFixed(1);
    const label = Math.abs(v) >= 10000 ? `${(v / 10000).toFixed(1)}万` : `${Math.round(v)}`;
    grid += `<line x1="${padL}" y1="${y}" x2="${w - padR}" y2="${y}" stroke="#e0e0e0" stroke-width="1"/>` +
      `<text x="${padL - 6}" y="${Number(y) + 4}" font-size="11" fill="#999" text-anchor="end">${label}</text>`;
  }
  let path = '';
  for (let i = 0; i < r.cashFlow.length; i++) {
    const x = (padL + plotW * i / (r.cashFlow.length - 1)).toFixed(1);
    const y = yOf(r.cashFlow[i]).toFixed(1);
    path += `${i === 0 ? 'M' : 'L'}${x},${y}`;
  }
  let months = '';
  for (let m = 1; m <= 12; m += 2) {
    const x = padL + plotW * (m - 1) / 11;
    months += `<text x="${x.toFixed(1)}" y="${h - 8}" font-size="11" fill="#999" text-anchor="middle">${m}月</text>`;
  }
  const zeroY = yOf(0).toFixed(1);
  return `<svg width="${w}" height="${h}" xmlns="http://www.w3.org/2000/svg">` +
    grid +
    `<line x1="${padL}" y1="${zeroY}" x2="${w - padR}" y2="${zeroY}" stroke="#666" stroke-width="1.5"/>` +
    `<path d="${path}" fill="none" stroke="#e8684a" stroke-width="2.5"/>` +
    months +
    `</svg>`;
}

function conclusionOf(p: Plan, r: SimResult): string {
  const parts: string[] = [];
  if (r.monthlyProfit <= 0) {
    parts.push(`当前假设下方案「${esc(p.name)}」月经营利润为 ${yuan(r.monthlyProfit)} 元，处于亏损状态，建议优先优化成本结构或提高客单价。`);
  } else {
    parts.push(`方案「${esc(p.name)}」月经营利润约 ${yuan(r.monthlyProfit)} 元，毛利率 ${r.grossMargin.toFixed(1)}%。`);
    parts.push(r.paybackMonths > 0
      ? `累计现金预计第 ${r.paybackMonths} 个月转正，年化 ROI ${r.annualRoi.toFixed(1)}%。`
      : `按当前假设 12 个月内累计现金无法转正（年化 ROI ${r.annualRoi.toFixed(1)}%）。`);
  }
  if (r.breakEvenDailyOrders >= 0) {
    parts.push(`盈亏平衡需要日均 ${r.breakEvenDailyOrders.toFixed(1)} 单，当前假设 ${p.dailyOrders.toFixed(0)} 单/天。`);
  }
  if (r.stoppedMonth > 0) {
    parts.push(`风险提示：按连续现金为负停业规则推演，方案将于第 ${r.stoppedMonth} 个月触发停业。`);
  }
  parts.push(`综合风险评级：${r.riskLevel}。`);
  return parts.join('');
}

export function generateReportHtml(p: Plan): string {
  const r = simulate(p);
  // 成本条目表
  const kindLabel: Record<string, string> = {
    'onetime': '一次性', 'monthly': '按月', 'perUnit': '按单', 'amortized': '按月摊销'
  };
  let costRows = '';
  for (const c of p.costItems) {
    costRows += `<tr><td>${esc(c.name)}</td><td>${kindLabel[c.kind]}</td><td>${yuan(c.amount)}</td>` +
      `<td>${c.kind === 'amortized' ? `${c.amortMonths} 个月` : (c.kind === 'monthly' ? `第 ${c.startMonth}-${c.endMonth} 月` : '-')}</td></tr>`;
  }
  // 12 月推演表
  let monthRows = '';
  for (const m of r.months) {
    monthRows += `<tr><td>${m.month}</td><td>${m.dailyOrders.toFixed(1)}</td><td>${yuan(m.revenue)}</td>` +
      `<td>${yuan(m.variableCost + m.fixedCost)}</td><td>${yuan(m.loanPay)}</td><td>${yuan(m.profit)}</td><td>${yuan(m.cash)}</td></tr>`;
  }
  const season = p.seasonCurve.map((v: number) => v.toFixed(2)).join(' / ');
  const loanText = p.loan.amount > 0
    ? `借款 ${yuan(p.loan.amount)} 元 · 年利率 ${p.loan.annualRate}% · ${p.loan.months} 期等额本息`
    : '无借款';

  return `<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<title>创业方案分析报告 - ${esc(p.name)}</title>
<style>
body{font-family:"Microsoft YaHei",sans-serif;max-width:760px;margin:24px auto;padding:0 16px;color:#333;}
h1{font-size:22px;border-bottom:3px solid #e8684a;padding-bottom:8px;}
h2{font-size:17px;margin-top:28px;color:#c0402b;}
table{width:100%;border-collapse:collapse;font-size:13px;margin:10px 0;}
th,td{border:1px solid #ddd;padding:6px 8px;text-align:left;}
th{background:#faf3f0;}
.kpi{display:flex;flex-wrap:wrap;gap:12px;}
.kpi div{flex:1;min-width:160px;border:1px solid #eee;border-radius:8px;padding:10px;}
.kpi b{display:block;font-size:18px;margin-top:4px;}
.note{color:#888;font-size:12px;}
footer{margin-top:32px;color:#aaa;font-size:11px;text-align:center;}
</style>
</head>
<body>
<h1>${esc(p.name)} · 成本收益分析报告</h1>
<p>类型：${esc(p.type)} &nbsp;|&nbsp; 风险评级：<b>${r.riskLevel}</b> &nbsp;|&nbsp; ${esc(p.note)}</p>

<h2>核心指标</h2>
<div class="kpi">
<div>启动投入<b>￥${yuan(r.startupTotal)}</b></div>
<div>月经营利润<b>￥${yuan(r.monthlyProfit)}</b></div>
<div>现金流转正<b>${r.paybackMonths > 0 ? `第 ${r.paybackMonths} 个月` : '12 个月内未转正'}</b></div>
<div>年化 ROI<b>${r.annualRoi.toFixed(1)}%</b></div>
</div>

<h2>成本假设</h2>
<table><tr><th>名称</th><th>类型</th><th>金额（元）</th><th>说明</th></tr>${costRows}</table>
<p class="note">资金：自筹 ${yuan(p.selfFunds)} 元；${loanText}；${p.staged.length > 0 ? '含阶段追加投资' : '无阶段追加'}。</p>

<h2>收入假设</h2>
<table>
<tr><th>客单价</th><td>${yuan(p.unitPrice)} 元/单</td><th>日均订单量</th><td>${p.dailyOrders} 单/天</td></tr>
<tr><th>月营业天数</th><td>${p.daysPerMonth} 天</td><th>月增长率 / 竞争流失</th><td>${p.monthlyGrowthRate}% / ${p.churnRate}%</td></tr>
<tr><th>季节系数（1-12 月）</th><td colspan="3">${season}</td></tr>
<tr><th>所需人力 / 场地</th><td colspan="3">${p.staffCount} 人 / ${p.areaSqm} ㎡</td></tr>
</table>

<h2>12 个月逐月推演</h2>
<table><tr><th>月份</th><th>日均单量</th><th>收入</th><th>成本</th><th>还款</th><th>当月损益</th><th>累计现金</th></tr>${monthRows}</table>

<h2>现金流走势</h2>
${cashFlowSvg(r)}

<h2>结论</h2>
<p>${conclusionOf(p, r)}</p>

<footer>本报告由「校园创业成本模拟器」在本地生成 · 全部计算离线完成</footer>
</body>
</html>`;
}
