// pixel-diff.mjs — HTML 原型路线逐卡内联视觉验收参考实现(jjspec 物料:按需登记级)
//
// 职责:基准图目录 vs 实现截图目录按文件名配对逐像素对比,输出每页差异百分比;
//       FAIL 页附差异热区 Top5(100×100 网格聚合:坐标区间+差异像素数+块内占比),供定向修复;
//       任一页超阈值即 exit 1(fail-closed)——对应 taskcard 拆卡规则 8「页面视觉验收逐卡内联」,
//       ui-gate 行 `pixel-diff <差异>% ≤ <PRD阈值>% PASS(命令:node pixel-diff.mjs ...)` 的可复跑命令本体。
//
// 依赖(项目侧按需登记,一次性安装):npm i -D pixelmatch pngjs
// 用法:node pixel-diff.mjs <基准目录> <实现截图目录> [--threshold 0.5]
//   基准目录  = 规范管线产出的 baselines/(冻结原型在执行环境重产的参考基准,guide 步 5 基准机制)
//   实现截图  = 项目 Playwright/截图脚本对实现页面采集的 PNG(文件名与基准一一对应,如 p-01.png)
// 注意:基准生成环境与执行环境不一致时,须以冻结原型在执行环境重产基准再对比(防跨环境渲染假阳性)。
// author: 李晶
import { readdirSync, readFileSync } from 'node:fs';
import { join, extname } from 'node:path';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

// parseArgs — 解析命令行:两个位置参数(基准目录/实现目录)+ 可选 --threshold(默认 0.5,单位 %)
const args = process.argv.slice(2);
const positional = args.filter((a) => !a.startsWith('--'));
const thresholdIdx = args.indexOf('--threshold');
const threshold = thresholdIdx > -1 ? Number(args[thresholdIdx + 1]) : 0.5;
if (positional.length < 2 || Number.isNaN(threshold)) {
  console.error('用法: node pixel-diff.mjs <基准目录> <实现截图目录> [--threshold 0.5]');
  process.exit(1);
}
const [baselineDir, actualDir] = positional;

// listPngs — 列出目录内全部 PNG 文件名(按名称配对的依据)
const listPngs = (dir) => readdirSync(dir).filter((f) => extname(f).toLowerCase() === '.png');

// hotspots — 差异热区统计:diff 图中非白像素(pixelmatch 相同像素写白)按 100×100 网格分桶,取差异像素数 Top5
// 用途:FAIL 页定向修复——AI 按热区坐标直接定位改动点,替代全页盲查(省逐轮截图-看图-猜的 token)
const hotspots = (diffData, width, height, block = 100, topN = 5) => {
  const buckets = new Map();
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      if (diffData[i] === 255 && diffData[i + 1] === 255 && diffData[i + 2] === 255) continue;
      const key = `${Math.floor(x / block)},${Math.floor(y / block)}`;
      buckets.set(key, (buckets.get(key) ?? 0) + 1);
    }
  }
  return [...buckets.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, topN)
    .map(([key, n]) => {
      const [bx, by] = key.split(',').map(Number);
      const x0 = bx * block, y0 = by * block;
      const x1 = Math.min(x0 + block, width) - 1, y1 = Math.min(y0 + block, height) - 1;
      const density = ((n / (block * block)) * 100).toFixed(1);
      return `      热区 x[${x0}-${x1}] y[${y0}-${y1}] 差异像素 ${n}(块内 ${density}%)`;
    });
};

// main — 配对→逐像素对比→逐页报告→阈值裁决(fail-closed:缺基准/缺实现/尺寸不一致/超阈值均 exit 1)
const baselines = listPngs(baselineDir);
const actuals = new Set(listPngs(actualDir));
if (baselines.length === 0) {
  console.error(`❌ 基准目录无 PNG:${baselineDir}——基准缺失 = 验收能力缺失,禁止以其他检查顶替(缺失即阻塞)`);
  process.exit(1);
}
let failed = 0;
for (const name of baselines) {
  if (!actuals.has(name)) {
    console.error(`🚫 ${name}:实现侧缺截图——页面未采集或漏跑,禁止跳过`);
    failed++;
    continue;
  }
  const a = PNG.sync.read(readFileSync(join(baselineDir, name)));
  const b = PNG.sync.read(readFileSync(join(actualDir, name)));
  if (a.width !== b.width || a.height !== b.height) {
    console.error(`🚫 ${name}:尺寸不一致(基准 ${a.width}x${a.height} vs 实现 ${b.width}x${b.height})——布局级偏差,判 FAIL`);
    failed++;
    continue;
  }
  const diffImg = new PNG({ width: a.width, height: a.height });
  const diff = pixelmatch(a.data, b.data, diffImg.data, a.width, a.height, { threshold: 0.1 });
  const pct = (diff / (a.width * a.height)) * 100;
  const ok = pct <= threshold;
  if (!ok) failed++;
  console.log(`  ${ok ? '✅' : '🚫'} ${name}:pixel-diff ${pct.toFixed(2)}% ${ok ? '≤' : '>'} ${threshold}% ${ok ? 'PASS' : 'FAIL'}`);
  if (!ok) {
    const hs = hotspots(diffImg.data, a.width, a.height);
    // 差异弥散(无集中热区)→ 环境不对齐的概率远大于样式错——重产基准优于逐块修样式
    console.log(hs.length > 0 ? hs.join('\n') : '      (差异弥散无集中热区——优先怀疑环境不对齐,以冻结原型重产基准再比)');
  }
}
if (failed > 0) {
  console.error(`❌ 视觉验收不通过:${failed} 页超标——逐卡内联验收 FAIL,打回该卡(taskcard 拆卡规则 8)`);
  // 热区排查顺序(命中率降序):差异率通常由一两个结构性原因贡献大头,按序定位优于全页盲调
  console.error('   热区排查顺序:① 字体落包(@font-face 真加载——回退系统字体=整段文本区差异,热区呈水平条带状) ② 环境重产基准 ③ 间距取 Token 精确值(±2px 容差在像素级不成立) ④ 动态区裁剪/掩码');
  process.exit(1);
}
console.log(`✅ 全部 ${baselines.length} 页 pixel-diff ≤ ${threshold}% PASS`);
