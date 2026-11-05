import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

// Fixed semantic markers, not a claim that every remaining MOCK string is a
// reachable fixture. Shared widgets also carry optional preview labels.
export const forbiddenMarkers = [
  '打开语音网关链路演练（MOCK）',
  '打开跨模块音频演练（MOCK）',
  '打开拨号权限演练（MOCK）',
  '打开开发者功能演练（MOCK）',
  '创建克隆交互演练（MOCK）',
  '进入联系人交互演练（MOCK）',
  '进入翻译通话演练（MOCK）',
  '文档交互演练（MOCK）',
  '图片交互演练（MOCK）',
  'MOCK · 选择文档场景',
  'MOCK · 选择合成图片场景',
];
export const requiredMarkers = [
  '固定外呼号码', '当前定位', '网络状态模拟', '列表状态',
  '重置所有权限', '我的身份', '导入文档', '20142014*#',
];

export function auditReleasePreviews(source) {
  // Decode text only; never evaluate a compiled application or its strings.
  const text = source.replace(/\\u([0-9a-f]{4})|\\x([0-9a-f]{2})/gi,
    (_, unicode, byte) => String.fromCharCode(parseInt(unicode ?? byte, 16)));
  const retainedPreviews = forbiddenMarkers.filter(marker => text.includes(marker));
  const missingRealEntries = requiredMarkers.filter(marker => !text.includes(marker));
  return {
    passed: retainedPreviews.length === 0 && missingRealEntries.length === 0,
    scope: 'Known Web release markers only; not native or complete route acceptance',
    forbiddenChecks: forbiddenMarkers.length,
    requiredChecks: requiredMarkers.length,
    retainedPreviews,
    missingRealEntries,
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const file = process.argv[2];
  if (!file || process.argv.length !== 3) {
    console.error('Usage: node scripts/web/audit-release-previews.mjs <main.dart.js>');
    process.exitCode = 2;
  } else {
    const result = auditReleasePreviews(await readFile(file, 'utf8'));
    console.log(JSON.stringify(result, null, 2));
    if (!result.passed) process.exitCode = 1;
  }
}
