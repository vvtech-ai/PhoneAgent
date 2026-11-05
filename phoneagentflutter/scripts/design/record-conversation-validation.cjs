const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),dir=path.join(root,'design/conversation-history');
const evidence=JSON.parse(fs.readFileSync(path.join(root,'.local/conversation-validation/result.json'),'utf8'));
const captures=['tasks','restored-voice','options','text-result'].map(name=>{
  const file=`.local/conversation-validation/${name}.png`;
  return {path:file,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex')};
});
const result=JSON.parse(fs.readFileSync(path.join(dir,'AutoValidationResult.json'),'utf8'));
Object.assign(result,{generatedAt:new Date().toISOString(),runtimeEvidence:{...evidence,captures},
  visualFidelityChecks:[{checkId:'conversation-readability',routeId:'pureVoicePage',region:'header/thread/composer',
    status:'pass',evidence:captures.map(c=>c.path),reason:'Screenshots inspected. Original SVG icons; task shadows and toggle corrected. No claim of pixel-identical/full-tool acceptance.'}],
  majorIssues:['复杂工具/回执/音频/完整阶段状态仍待迁移；基础文字范围以验证文档为准'],
  minorIssues:['iOS与真实账号联调待集中验证'],shouldSelfFix:false,
  stopReason:'scoped-foundation-verified; continue read-only result detail; no full-app score assigned'});
fs.writeFileSync(path.join(dir,'AutoValidationResult.json'),JSON.stringify(result,null,2)+'\n');
