// visual-diagnose.mjs — HTML 原型路线 pixel-diff FAIL 页热区级 DOM/CSS 诊断(jjspec 物料:按需登记级)
//
// 职责:消费 pixel-diff.mjs --out 产出的 report.json,对指定超阈值页逐热区在实现页渲染态采样——
//       按热区几何采样点(中心 + 四分位共 5 点)做 elementsFromPoint,输出命中元素链(tag#id.class
//       + 文本片段)+ 计算样式(排版/盒模型/定位/布局/裁切/视觉效果)+ boundingBox,
//       产出逐热区 markdown 诊断报告。AI 拿报告与页面规格「## 节点样式量化表」期望值对读归因,
//       把"差异在哪"升级为"该改哪个元素的哪个属性"(修复节奏与停止条件见 ui-spec-guide
//       「HTML 路线 pixel-diff FAIL 修复闭环」;本脚本只承载数据,不做归因结论)。
//
// 坐标换算:热区坐标属截图图像素空间;缩放比 = 实现截图宽 ÷ env.json viewport 宽(DPR 与 fullPage
//           由此消化),采样点 = 图像坐标 ÷ 缩放比换算为 CSS 坐标后入页采样——禁止直接以图像坐标
//           调 elementsFromPoint;截图宽偏离 viewport.width×dpr 超 2% 时告警(截图与登记环境可疑不一致)。
// 环境契约:实现侧 env.json 必须存在且含 viewport.width/height 与 dpr(采样坐标与元素样式由其决定,
//           缺失即 fail-closed);渲染后等待 document.fonts.ready(与 fontsReady=true 契约对齐);
//           热区采样经滚动定位,box 输出为文档坐标(×缩放比即截图像素坐标,可与热区三联裁剪图互相对位)。
//
// 依赖(项目侧按需登记):npm i -D playwright pngjs
// 用法:node visual-diagnose.mjs <实现页URL> <实现截图目录> <report.json> <页名.png> [--out <诊断md路径>]
//   页名  = report.json pages[].name(如 p-02.png),须为超阈值页(hotspots 非空)——缺截图/尺寸不一致页
//           无像素级热区,不属本脚本服务范围,报错退出
//   --out = 可选。默认 <report.json 同目录>/diagnose/<页名去后缀>.diagnose.md
// author: 李晶
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { PNG } from 'pngjs';
import { chromium } from 'playwright';

// usageErr — 参数不合法的统一出口:打印用法后 fail-closed 退出
const usageErr = (msg) => {
  console.error(`用法: node visual-diagnose.mjs <实现页URL> <实现截图目录> <report.json> <页名.png> [--out <诊断md路径>]\n错误:${msg}`);
  process.exit(1);
};

// parseArgs — 逐参数扫描解析:位置参数恰为 4 个(实现页URL/实现截图目录/report.json/页名);--out 须跟路径;未知参数拦截
const parseArgs = (argv) => {
  const positional = [];
  let outPath;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--out') {
      outPath = argv[++i];
      if (outPath === undefined || outPath.startsWith('--')) usageErr('--out 须跟诊断报告输出路径');
    } else if (argv[i].startsWith('--')) {
      usageErr(`未知参数:${argv[i]}`);
    } else {
      positional.push(argv[i]);
    }
  }
  if (positional.length !== 4) usageErr(`位置参数须恰为 4 个(实现页URL 实现截图目录 report.json 页名),收到 ${positional.length} 个`);
  const [url, actualDir, reportPath, pageName] = positional;
  if (!/^https?:\/\//.test(url)) usageErr(`实现页 URL 须以 http(s):// 开头,收到:${url}`);
  if (!pageName.endsWith('.png')) usageErr(`页名须为 report.json 内的 PNG 文件名(如 p-02.png),收到:${pageName}`);
  return { url, actualDir, reportPath, pageName, outPath };
};

// loadEnvStrict — 实现侧 env.json 必须存在且登记完整:采样坐标换算与渲染环境均由其决定,
// 缺失/不合法视同无契约(fail-closed)——与 pixel-diff 的 WARN 渐进采用不同,诊断是第二步,前置条件应更严
const loadEnvStrict = (actualDir) => {
  let raw;
  try {
    raw = readFileSync(join(actualDir, 'env.json'), 'utf8');
  } catch {
    console.error(`❌ 实现侧 env.json 缺失(${join(actualDir, 'env.json')})——采样环境无契约,诊断结果无效;先按 pixel-diff 头部注释格式登记`);
    process.exit(1);
  }
  let env;
  try {
    env = JSON.parse(raw);
  } catch (e) {
    console.error(`❌ 实现侧 env.json 解析失败:${e.message}——登记不合法视同无契约`);
    process.exit(1);
  }
  if (!env.viewport?.width || !env.viewport?.height || !env.dpr) {
    console.error('❌ env.json 缺 viewport.width/height 或 dpr——采样坐标换算依赖这三项,登记不完整视同无契约');
    process.exit(1);
  }
  return env;
};

// loadTargetPage — 从 report.json 取目标页记录:须存在且 ok=false 且 hotspots 非空;
// 缺截图/尺寸不一致页无像素级热区,不属本脚本服务范围
const loadTargetPage = (reportPath, pageName) => {
  let report;
  try {
    report = JSON.parse(readFileSync(reportPath, 'utf8'));
  } catch (e) {
    console.error(`❌ report.json 读取或解析失败(${reportPath}):${e.message}——先用 pixel-diff --out 产出报告`);
    process.exit(1);
  }
  const rec = (report.pages ?? []).find((p) => p.name === pageName);
  if (!rec) {
    const known = (report.pages ?? []).map((p) => p.name).join(', ') || '无';
    usageErr(`report.json 中无页名 ${pageName}(已有:${known})`);
  }
  if (rec.ok !== false || !Array.isArray(rec.hotspots) || rec.hotspots.length === 0) {
    usageErr(`${pageName} 非超阈值页或无像素级热区(ok=${rec.ok}${rec.error ? `, error=${rec.error}` : ''})——本脚本仅服务超阈值页`);
  }
  return { rec, threshold: report.threshold };
};

// samplePage — 页面内采样器:文档坐标逐点滚动至视口中央 → elementsFromPoint 取前 3 层元素,
// 输出 selector/文本/文档坐标 box/关键计算样式(与截图热区对位靠文档坐标 × 缩放比)
const samplePage = (pg, docPoints) => pg.evaluate((pts) => {
  // pick — 单元素信息采集:selector(tag#id.前3个class)+ 文本片段 + 文档坐标 box + 计算样式
  const pick = (el) => {
    if (!el || el === document.documentElement || el === document.body) return null;
    const cs = getComputedStyle(el);
    const r = el.getBoundingClientRect();
    const cls = [...el.classList].slice(0, 3).join('.');
    return {
      sel: `${el.tagName.toLowerCase()}${el.id ? `#${el.id}` : ''}${cls ? `.${cls}` : ''}`,
      text: (el.innerText || '').trim().slice(0, 30),
      box: { x: Math.round(r.x), y: Math.round(r.y + window.scrollY), w: Math.round(r.width), h: Math.round(r.height) },
      styles: {
        font: `${cs.fontSize} / ${cs.lineHeight} ${cs.fontFamily} ${cs.fontWeight}`,
        letterSpacing: cs.letterSpacing,
        color: cs.color,
        background: cs.backgroundColor,
        backgroundImage: cs.backgroundImage !== 'none' ? cs.backgroundImage : undefined,
        display: cs.display,
        position: cs.position,
        boxSizing: cs.boxSizing,
        padding: cs.padding,
        margin: cs.margin,
        layout: [cs.flexDirection !== 'row' ? `flex-direction ${cs.flexDirection}` : '',
          cs.justifyContent !== 'normal' ? `justify ${cs.justifyContent}` : '',
          cs.alignItems !== 'normal' ? `align ${cs.alignItems}` : '',
          cs.gap !== 'normal' ? `gap ${cs.gap}` : '',
          cs.gridTemplateColumns !== 'none' ? `grid-cols ${cs.gridTemplateColumns}` : '',
          cs.gridTemplateRows !== 'none' ? `grid-rows ${cs.gridTemplateRows}` : ''].filter(Boolean).join('; ') || undefined,
        overflow: cs.overflow !== 'visible' ? cs.overflow : undefined,
        textLayout: [cs.whiteSpace !== 'normal' ? `white-space ${cs.whiteSpace}` : '',
          cs.textOverflow !== 'clip' ? `text-overflow ${cs.textOverflow}` : ''].filter(Boolean).join('; ') || undefined,
        imageFit: el instanceof HTMLImageElement ? `${cs.objectFit} ${cs.objectPosition}` : undefined,
        opacity: cs.opacity !== '1' ? cs.opacity : undefined,
        transform: cs.transform !== 'none' ? cs.transform : undefined,
        border: cs.borderWidth === '0px' ? undefined : `${cs.borderWidth} ${cs.borderStyle} ${cs.borderColor}`,
        radius: cs.borderRadius,
        shadow: cs.boxShadow !== 'none' ? cs.boxShadow : undefined,
      },
    };
  };
  // 逐点滚动定位后采样;fixed/sticky 元素以滚动后视口位置为准(采样窗口即当时视口)
  return pts.map(([dx, dy]) => {
    window.scrollTo(0, Math.max(0, dy - window.innerHeight / 2));
    const vy = dy - window.scrollY;
    if (vy < 0 || vy > window.innerHeight) return []; // 滚动钳制后点仍在视口外(文档比预期短),放弃该点
    return document.elementsFromPoint(dx, vy).slice(0, 3).map(pick).filter(Boolean);
  });
}, docPoints);

// fmtEl — 单元素 markdown 片段:selector + 命中次数 + 文本 + box(含截图像素换算)+ 计算样式分组行
const fmtEl = (el, scale) => {
  const s = el.styles;
  const line = (label, v) => (v === undefined ? '' : `\n    - ${label}: ${v}`);
  return `  - \`${el.sel}\` ×${el.hits}${el.text ? ` 文本「${el.text}」` : ''}`
    + `\n    - box(文档坐标): x=${el.box.x} y=${el.box.y} w=${el.box.w} h=${el.box.h}(×${scale} = 截图像素 y=${Math.round(el.box.y * scale)},可对位热区三联裁剪图)`
    + line('font', s.font)
    + line('letter spacing', s.letterSpacing)
    + line('color', s.color)
    + line('background', [s.background, s.backgroundImage].filter(Boolean).join(' + '))
    + line('layout', s.layout)
    + line('spacing', `padding ${s.padding} / margin ${s.margin}`)
    + line('position / box', `${s.position} / ${s.display} / ${s.boxSizing}`)
    + line('overflow / text', [s.overflow, s.textLayout].filter(Boolean).join(' / '))
    + line('image fit', s.imageFit)
    + line('opacity / transform', [s.opacity, s.transform].filter(Boolean).join(' / '))
    + line('border', s.border)
    + line('radius', s.radius)
    + line('shadow', s.shadow);
};

// genMarkdown — 诊断报告 markdown:头部(页信息/采样环境/规则指针)+ 逐热区命中元素清单
const genMarkdown = (url, env, scale, rec, threshold, hotspotReports) => {
  const head = [
    `# 视觉诊断报告 — ${rec.name}`,
    '',
    `- URL: ${url}`,
    `- pixel-diff: 差异率 ${rec.pct}%(热区 Top5 覆盖 ${rec.topShare ?? '—'}%),报告阈值 ${threshold}%`,
    `- 采样环境: viewport ${env.viewport.width}×${env.viewport.height} / dpr ${env.dpr} / 缩放比 ${scale}(来自实现侧 env.json)`,
    `- 用法: 与页面规格「## 节点样式量化表」期望值对读归因,定位到元素与属性后再改;`,
    `  修复节奏与停止条件见 ui-spec-guide「HTML 路线 pixel-diff FAIL 修复闭环」`,
    '',
  ];
  const body = hotspotReports.map((h, i) => {
    const r = h.rect;
    const elems = h.elements.length > 0
      ? h.elements.map((el) => fmtEl(el, scale)).join('\n')
      : '  - (采样点未命中任何元素——热区可能落在文档外或空白区,核对截图与页面高度)';
    return `## 热区 ${i + 1} — x[${r.x0}-${r.x1}] y[${r.y0}-${r.y1}] 差异像素 ${r.diffPixels}(块内 ${r.density}%)\n\n${elems}`;
  });
  return [...head, ...body, ''].join('\n');
};

const { url, actualDir, reportPath, pageName, outPath } = parseArgs(process.argv.slice(2));
const env = loadEnvStrict(actualDir);
const { rec, threshold } = loadTargetPage(reportPath, pageName);

// 缩放比与截图宽度一致性告警:截图宽应 ≈ viewport.width × dpr,偏离超 2% 说明截图与登记环境可疑不一致
const shot = PNG.sync.read(readFileSync(join(actualDir, pageName)));
const scale = shot.width / env.viewport.width;
const expectW = env.viewport.width * env.dpr;
if (Math.abs(shot.width - expectW) > expectW * 0.02) {
  console.warn(`⚠️  实现截图宽 ${shot.width} ≠ viewport.width×dpr(${expectW})——截图与登记环境可能不一致,采样坐标仅供参考`);
}

// 采样点生成:每热区中心 + 四分位 5 点,图像坐标 ÷ 缩放比 → CSS 文档坐标
const cssRects = rec.hotspots.map((h) => ({
  ...h,
  x: h.x0 / scale,
  y: h.y0 / scale,
  w: (h.x1 - h.x0 + 1) / scale,
  h: (h.y1 - h.y0 + 1) / scale,
}));
const docPoints = cssRects.flatMap((r) => [
  [r.x + r.w / 2, r.y + r.h / 2],
  [r.x + r.w * 0.25, r.y + r.h * 0.25],
  [r.x + r.w * 0.75, r.y + r.h * 0.25],
  [r.x + r.w * 0.25, r.y + r.h * 0.75],
  [r.x + r.w * 0.75, r.y + r.h * 0.75],
]);

const browser = await chromium.launch();
let sampled;
try {
  const context = await browser.newContext({
    viewport: { width: env.viewport.width, height: env.viewport.height },
    deviceScaleFactor: env.dpr,
    ...(env.userAgent ? { userAgent: env.userAgent } : {}),
  });
  const pg = await context.newPage();
  try {
    await pg.goto(url, { waitUntil: 'networkidle' });
  } catch (e) {
    console.error(`❌ 实现页无法访问(${url}):${e.message.split('\n')[0]}——核对服务是否启动、URL 是否正确`);
    process.exit(1);
  }
  await pg.evaluate(() => document.fonts.ready); // 字体就绪后采样,与 env.json fontsReady=true 契约对齐
  sampled = await samplePage(pg, docPoints);
  await browser.close();
} catch (e) {
  console.error(`❌ 浏览器采样失败:${e.message.split('\n')[0]}`);
  process.exit(1);
}

// 逐热区归组去重:同 selector+box 在多点命中合并计数,按命中点数降序(命中最多的最可能是差异主体)
const hotspotReports = cssRects.map((r, i) => {
  const seen = new Map();
  sampled.slice(i * 5, i * 5 + 5).flat().forEach((el) => {
    const key = `${el.sel}@${el.box.x},${el.box.y},${el.box.w},${el.box.h}`;
    if (!seen.has(key)) seen.set(key, { ...el, hits: 0 });
    seen.get(key).hits++;
  });
  return { rect: r, elements: [...seen.values()].sort((a, b) => b.hits - a.hits) };
});

const mdPath = outPath ?? join(dirname(reportPath), 'diagnose', `${pageName.replace(/\.png$/i, '')}.diagnose.md`);
mkdirSync(dirname(mdPath), { recursive: true });
writeFileSync(mdPath, genMarkdown(url, env, scale, rec, threshold, hotspotReports));
const totalElems = hotspotReports.reduce((s, h) => s + h.elements.length, 0);
console.log(`✅ 诊断报告已输出 ${mdPath}(${rec.hotspots.length} 热区 / ${totalElems} 命中元素)——与页面规格量化表对读归因`);
