// pixel-diff.mjs — HTML 原型路线逐卡内联视觉验收参考实现(jjspec 物料:按需登记级)
//
// 职责:基准图目录 vs 实现截图目录按文件名配对逐像素对比,输出每页差异百分比;
//       FAIL 页附差异热区 Top5(100×100 网格聚合:坐标区间+差异像素数+块内占比)——热区判定与
//       差异百分比同源(pixelmatch diffMask 模式:非黑=计入差异),且热区总计数与 diff 返回值
//       强制对账,不等即 fail-closed,杜绝"热区反映图像内容而非差异"的误导;
//       双向文件校验:基准有实现无 / 实现有基准无 均 FAIL(多出的截图=新页面未建基准,静默通过=验收遗漏);
//       截图环境 sidecar(env.json)登记后机械校验视口/DPR/UA/字体就绪,防环境噪声假阳性;
//       任一失败即 exit 1(fail-closed)——对应 taskcard 拆卡规则 8「页面视觉验收逐卡内联」,
//       ui-gate 行 `pixel-diff <差异>% ≤ <PRD阈值>% PASS(命令:node pixel-diff.mjs ...)` 的可复跑命令本体。
//
// 依赖(项目侧按需登记,一次性安装):npm i -D pixelmatch pngjs
// 用法:node pixel-diff.mjs <基准目录> <实现截图目录> [--threshold 0.5] [--out <输出目录>]
//   基准目录  = 规范管线产出的 baselines/(冻结原型在执行环境重产的参考基准,guide 步 5 基准机制)
//   实现截图  = 项目 Playwright/截图脚本对实现页面采集的 PNG(文件名与基准一一对应,如 p-01.png)
//   --out     = 可选。指定后 FAIL 页物化:整页差异图 <页名>.diff.png(黑底红标)+ 叠加图 <页名>.overlay.png
//               (基准/实现 50% 混合,错位类差异呈重影)+ 每热区三联裁剪 <页名>.h<序号>.{base,actual,hdiff}.png
//               (含 16px 上下文)——把"差异在哪"变成"该改哪个元素"的判读依据;
//               另落 report.json(逐页差异率/热区坐标的机器可读报告,供 visual-diagnose.mjs 消费)
//
// 环境契约 sidecar(强制):截图采集脚本在基准/实现目录各落一份 env.json(每环境一份,非每页一份):
//   {"viewport":{"width":390,"height":844},"dpr":2,"userAgent":"Mozilla/5.0 ...","fontsReady":true}
//   两侧均须登记 → 机械校验:viewport/dpr/userAgent 逐字段一致且 fontsReady 双侧为 true;缺失/不完整/不一致均整批 FAIL
//   (环境不一致产生的差异百分比无意义)。登录态、数据状态、浏览器版本与动画关闭由采集流程固定。
//
// 注意:①基准生成环境与执行环境不一致时,须以冻结原型在执行环境重产基准再对比(防跨环境渲染假阳性);
//       ②--threshold 是差异百分比验收阈值(0<t≤100),pixelmatch 内部感知判定阈值固定 0.1
//       (OKLab HyAB 距离,0~1),两者语义无关,勿混淆。
// author: 李晶
import { readdirSync, readFileSync, writeFileSync, mkdirSync, statSync } from 'node:fs';
import { join, extname, resolve } from 'node:path';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

// usageErr — 参数不合法的统一出口:打印用法后 fail-closed 退出
const usageErr = (msg) => {
  console.error(`用法: node pixel-diff.mjs <基准目录> <实现截图目录> [--threshold 0.5] [--out <输出目录>]\n错误:${msg}`);
  process.exit(1);
};

// parseArgs — 逐参数扫描解析:位置参数必须恰为 2 个;--threshold 限 0<t≤100 且其值不混入位置参数;
// --out 须跟目录;未知参数直接拦截(替代旧 filter 写法——旧写法会把 threshold 值当第三个位置参数静默忽略)
const parseArgs = (argv) => {
  const positional = [];
  let threshold = 0.5;
  let outDir;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--threshold') {
      const v = Number(argv[++i]);
      if (argv[i] === undefined || Number.isNaN(v) || v <= 0 || v > 100) {
        usageErr(`--threshold 须为 0<t≤100 的数字(百分比),收到:${argv[i]}`);
      }
      threshold = v;
    } else if (argv[i] === '--out') {
      outDir = argv[++i];
      if (outDir === undefined || outDir.startsWith('--')) usageErr('--out 须跟输出目录路径');
    } else if (argv[i].startsWith('--')) {
      usageErr(`未知参数:${argv[i]}`);
    } else {
      positional.push(argv[i]);
    }
  }
  if (positional.length !== 2) usageErr(`位置参数须恰为 2 个(基准目录 实现截图目录),收到 ${positional.length} 个`);
  return { baselineDir: positional[0], actualDir: positional[1], threshold, outDir };
};

// loadEnv — 读取目录下 env.json 环境契约 sidecar;缺失返回 null;存在但 JSON 不合法视同未对齐,fail-closed
const loadEnv = (dir, tag) => {
  let raw;
  try {
    raw = readFileSync(join(dir, 'env.json'), 'utf8');
  } catch {
    return null;
  }
  try {
    return JSON.parse(raw);
  } catch (e) {
    console.error(`❌ ${tag}侧 env.json 解析失败(${join(dir, 'env.json')}):${e.message}——环境契约登记不合法视同未对齐`);
    process.exit(1);
  }
};

// checkEnvs — 环境契约前置校验:两侧都必须登记完整环境(viewport/dpr/userAgent 相等、fontsReady 均 true),
// 缺失/不完整/不一致均整批作废,避免用不可复现的环境噪声消耗视觉修复轮次
const checkEnvs = (baselineDir, actualDir) => {
  const base = loadEnv(baselineDir, '基准');
  const act = loadEnv(actualDir, '实现');
  if (!base || !act) {
    console.error(`❌ 环境契约缺失:基准=${base ? '有' : '无'} 实现=${act ? '有' : '无'} env.json——先补齐再执行,否则 0.5% 结果不可复现`);
    process.exit(1);
  }
  const problems = [];
  // cmp — 单字段等值比对,不等则记入问题清单(含 undefined:登记不完整 = 不对齐)
  const cmp = (label, a, b) => {
    if (a !== b) problems.push(`${label}:基准 ${JSON.stringify(a)} vs 实现 ${JSON.stringify(b)}`);
  };
  cmp('viewport.width', base.viewport?.width, act.viewport?.width);
  cmp('viewport.height', base.viewport?.height, act.viewport?.height);
  cmp('dpr', base.dpr, act.dpr);
  cmp('userAgent', base.userAgent, act.userAgent);
  for (const [tag, env] of [['基准', base], ['实现', act]]) {
    if (!Number.isFinite(env.viewport?.width) || env.viewport.width <= 0) problems.push(`${tag} viewport.width 须为正数`);
    if (!Number.isFinite(env.viewport?.height) || env.viewport.height <= 0) problems.push(`${tag} viewport.height 须为正数`);
    if (!Number.isFinite(env.dpr) || env.dpr <= 0) problems.push(`${tag} dpr 须为正数`);
    if (typeof env.userAgent !== 'string' || env.userAgent.length === 0) problems.push(`${tag} userAgent 必填`);
  }
  if (base.fontsReady !== true) problems.push(`基准 fontsReady=${JSON.stringify(base.fontsReady)} 须为 true(字体未就绪的截图无效)`);
  if (act.fontsReady !== true) problems.push(`实现 fontsReady=${JSON.stringify(act.fontsReady)} 须为 true(字体未就绪的截图无效)`);
  if (problems.length > 0) {
    console.error('❌ 环境契约不对齐,整批作废(环境不一致产生的差异百分比无意义,先对齐环境或重产基准):');
    problems.forEach((p) => console.error(`   - ${p}`));
    process.exit(1);
  }
  console.log('✅ 环境契约对齐(viewport/dpr/userAgent/fontsReady)');
};

// hotspots — 差异热区统计:diffMask 模式下非黑像素=被计入差异的像素(与 diff 返回值同一判定源),
// 按 100×100 网格分桶取 Top5;总计数与 pixelmatch 返回值强制对账,不等=判定口径分裂,fail-closed;
// 返回 { lines, topShare, rects }:topShare 为 Top5 差异占差异总数比例(弥散判定依据),rects 供裁剪物化
const hotspots = (diffData, width, height, expectedTotal, block = 100, topN = 5) => {
  const buckets = new Map();
  let total = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      if (diffData[i] === 0 && diffData[i + 1] === 0 && diffData[i + 2] === 0) continue; // 黑=无差异(diffMask 语义)
      total++;
      const key = `${Math.floor(x / block)},${Math.floor(y / block)}`;
      buckets.set(key, (buckets.get(key) ?? 0) + 1);
    }
  }
  if (total !== expectedTotal) {
    console.error(`❌ 内部对账失败:diffMask 热区计数 ${total} ≠ pixelmatch 差异总数 ${expectedTotal}——判定口径分裂,统计不可信`);
    process.exit(1);
  }
  const top = [...buckets.entries()].sort((a, b) => b[1] - a[1]).slice(0, topN);
  const topTotal = top.reduce((s, [, n]) => s + n, 0);
  const rects = [];
  const lines = top.map(([key, n]) => {
    const [bx, by] = key.split(',').map(Number);
    const x0 = bx * block, y0 = by * block;
    const x1 = Math.min(x0 + block, width) - 1, y1 = Math.min(y0 + block, height) - 1;
    const density = ((n / (block * block)) * 100).toFixed(1);
    // rects 同步携带机器可读数据(差异像素数/块内占比),report.json 与热区三联共用此结构
    rects.push({ x0, y0, x1, y1, diffPixels: n, density: Number(density) });
    return `      热区 x[${x0}-${x1}] y[${y0}-${y1}] 差异像素 ${n}(块内 ${density}%)`;
  });
  return { lines, rects, topShare: expectedTotal > 0 ? topTotal / expectedTotal : 1 };
};

// cropPng — 从源图裁剪 x0,y0 起 w×h 区域生成新 PNG(热区三联裁剪用,越界已由调用方 clamp)
const cropPng = (src, x0, y0, w, h) => {
  const out = new PNG({ width: w, height: h });
  for (let row = 0; row < h; row++) {
    const srcStart = ((y0 + row) * src.width + x0) * 4;
    src.data.copy(out.data, row * w * 4, srcStart, srcStart + w * 4);
  }
  return out;
};

// writeDiffArtifacts — FAIL 页物化(--out 时):整页差异图(黑底红标)+ 叠加图(基准/实现 50% 混合)
// + 每热区三联裁剪(基准/实现/差异各一张,外扩 16px 上下文),供"参考长什么样/实际长什么样/差在哪"判读;
// 叠加图与差异图互补:逐像素标记看"差了什么",重影看"错位了多少"(位置偏移类差异在叠加图呈双边)
const writeDiffArtifacts = (outDir, name, base, actual, diffImg, rects, pad = 16) => {
  mkdirSync(outDir, { recursive: true });
  const stem = name.replace(/\.png$/i, '');
  for (let i = 3; i < diffImg.data.length; i += 4) diffImg.data[i] = 255; // diffMask 非差异像素 alpha=0,统一置黑底便于判读
  writeFileSync(join(outDir, `${stem}.diff.png`), PNG.sync.write(diffImg));
  // overlay — 基准/实现逐通道 50% 混合(尺寸已由前置校验保证一致;不透明,免看图软件 alpha 处理差异)
  const overlay = new PNG({ width: base.width, height: base.height });
  for (let i = 0; i < overlay.data.length; i += 4) {
    overlay.data[i] = (base.data[i] + actual.data[i]) >> 1;
    overlay.data[i + 1] = (base.data[i + 1] + actual.data[i + 1]) >> 1;
    overlay.data[i + 2] = (base.data[i + 2] + actual.data[i + 2]) >> 1;
    overlay.data[i + 3] = 255;
  }
  writeFileSync(join(outDir, `${stem}.overlay.png`), PNG.sync.write(overlay));
  rects.forEach((r, idx) => {
    const x0 = Math.max(0, r.x0 - pad), y0 = Math.max(0, r.y0 - pad);
    const x1 = Math.min(base.width - 1, r.x1 + pad), y1 = Math.min(base.height - 1, r.y1 + pad);
    const w = x1 - x0 + 1, h = y1 - y0 + 1;
    const tag = `${stem}.h${idx + 1}`;
    writeFileSync(join(outDir, `${tag}.base.png`), PNG.sync.write(cropPng(base, x0, y0, w, h)));
    writeFileSync(join(outDir, `${tag}.actual.png`), PNG.sync.write(cropPng(actual, x0, y0, w, h)));
    writeFileSync(join(outDir, `${tag}.hdiff.png`), PNG.sync.write(cropPng(diffImg, x0, y0, w, h)));
  });
  console.log(`      差异图与 ${rects.length} 组热区三联已输出至 ${outDir}/`);
};

const { baselineDir, actualDir, threshold, outDir } = parseArgs(process.argv.slice(2));

// assertDir — 目录存在性前置校验:路径不存在/不是目录时给 fail-closed 中文报错
// (替代 readdirSync 的原始 ENOENT 堆栈——路径写错是最常见误用,报错须可执行:先补齐目录再验收)
const assertDir = (dir, tag) => {
  let st;
  try {
    st = statSync(dir);
  } catch {
    console.error(`❌ ${tag}目录不存在:${dir}——路径写错或目录未产出,先补齐该目录再验收`);
    process.exit(1);
  }
  if (!st.isDirectory()) {
    console.error(`❌ ${tag}路径不是目录:${dir}——两个位置参数均须为 PNG 目录`);
    process.exit(1);
  }
};
assertDir(baselineDir, '基准');
assertDir(actualDir, '实现');
// 同路径拦截:基准与实现传同一目录时每页与自身对比,必然 0% 静默全绿,验收结果无意义
if (resolve(baselineDir) === resolve(actualDir)) {
  console.error(`❌ 基准目录与实现目录为同一路径(${resolve(baselineDir)})——每页将与自身对比必然全绿,禁止执行`);
  process.exit(1);
}

checkEnvs(baselineDir, actualDir);

// listPngs — 列出目录内全部 PNG 文件名(按名称配对的依据)
const listPngs = (dir) => readdirSync(dir).filter((f) => extname(f).toLowerCase() === '.png');

// main — 配对→逐像素对比→逐页报告→阈值裁决(fail-closed:缺基准/缺实现/多截图/尺寸不一致/超阈值均 exit 1)
const baselines = listPngs(baselineDir);
const actuals = new Set(listPngs(actualDir));
if (baselines.length === 0) {
  console.error(`❌ 基准目录无 PNG:${baselineDir}——基准缺失 = 验收能力缺失,禁止以其他检查顶替(缺失即阻塞)`);
  process.exit(1);
}
let failed = 0;
// report — 机器可读逐页报告(--out 时落 report.json):热区坐标/差异像素数供 visual-diagnose.mjs 消费,
// 无需人眼从控制台抄坐标;人读结论以控制台为准,此文件只承载数据
const report = { threshold, baselineDir, actualDir, pages: [] };
// 双向集合校验:两个方向都判 FAIL,杜绝"实现多交截图无基准仍全绿"的验收遗漏
for (const name of baselines) {
  if (!actuals.has(name)) {
    console.error(`🚫 ${name}:实现侧缺截图——页面未采集或漏跑,禁止跳过`);
    report.pages.push({ name, pct: null, ok: false, error: '实现侧缺截图' });
    failed++;
  }
}
for (const name of [...actuals].filter((n) => !baselines.includes(n)).sort()) {
  console.error(`🚫 ${name}:实现侧多出截图但无对应基准——新增页面须先建基准,禁止静默通过`);
  report.pages.push({ name, pct: null, ok: false, error: '实现侧多出截图但无对应基准' });
  failed++;
}
for (const name of baselines.filter((n) => actuals.has(n))) {
  const a = PNG.sync.read(readFileSync(join(baselineDir, name)));
  const b = PNG.sync.read(readFileSync(join(actualDir, name)));
  if (a.width !== b.width || a.height !== b.height) {
    console.error(`🚫 ${name}:尺寸不一致(基准 ${a.width}x${a.height} vs 实现 ${b.width}x${b.height})——布局级偏差,判 FAIL`);
    report.pages.push({ name, pct: null, ok: false, error: `尺寸不一致(基准 ${a.width}x${a.height} vs 实现 ${b.width}x${b.height})` });
    failed++;
    continue;
  }
  const diffImg = new PNG({ width: a.width, height: a.height });
  // 感知判定阈值 0.1(OKLab)固定;diffMask:true → 无差异像素写黑,热区判定与 diff 返回值同源
  const diff = pixelmatch(a.data, b.data, diffImg.data, a.width, a.height, { threshold: 0.1, diffMask: true });
  const pct = (diff / (a.width * a.height)) * 100;
  const ok = pct <= threshold;
  if (!ok) failed++;
  console.log(`  ${ok ? '✅' : '🚫'} ${name}:pixel-diff ${pct.toFixed(2)}% ${ok ? '≤' : '>'} ${threshold}% ${ok ? 'PASS' : 'FAIL'}`);
  const rec = { name, pct: Number(pct.toFixed(2)), ok };
  if (!ok) {
    const hs = hotspots(diffImg.data, a.width, a.height, diff);
    rec.topShare = Number((hs.topShare * 100).toFixed(1));
    rec.hotspots = hs.rects;
    if (hs.lines.length > 0) console.log(hs.lines.join('\n'));
    // 差异弥散(Top5 热区覆盖 <30% 差异像素)→ 无主导改动点,环境不对齐的概率远大于样式错——重产基准优于逐块修样式
    if (hs.topShare < 0.3) {
      console.log(`      (差异弥散:Top5 热区仅覆盖 ${(hs.topShare * 100).toFixed(1)}% 差异像素,无集中热区——优先怀疑环境不对齐,以冻结原型重产基准再比)`);
    }
    if (outDir) writeDiffArtifacts(outDir, name, a, b, diffImg, hs.rects);
  }
  report.pages.push(rec);
}
if (outDir) {
  mkdirSync(outDir, { recursive: true });
  writeFileSync(join(outDir, 'report.json'), JSON.stringify(report, null, 2));
  console.log(`      机器可读报告已输出 ${join(outDir, 'report.json')}(超阈值页热区坐标供 visual-diagnose.mjs 采样)`);
}
if (failed > 0) {
  console.error(`❌ 视觉验收不通过:${failed} 页超标——逐卡内联验收 FAIL,打回该卡(taskcard 拆卡规则 8)`);
  // 热区排查顺序(命中率降序):差异率通常由一两个结构性原因贡献大头,按序定位优于全页盲调
  console.error('   热区排查顺序:① 字体落包(@font-face 真加载——回退系统字体=整段文本区差异,热区呈水平条带状) ② 环境对齐(env.json 登记+重产基准) ③ 间距取 Token 精确值(±2px 容差在像素级不成立) ④ 动态区裁剪/掩码');
  process.exit(1);
}
console.log(`✅ 全部 ${baselines.length} 页 pixel-diff ≤ ${threshold}% PASS`);
