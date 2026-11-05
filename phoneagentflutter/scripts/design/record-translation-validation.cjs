const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),dir=path.join(root,'design/translation-history');
const evidence=JSON.parse(fs.readFileSync(path.join(root,'.local/conversation-validation/result.json'),'utf8'));
const file='.local/conversation-validation/translation-history.png';
const result=JSON.parse(fs.readFileSync(path.join(dir,'AutoValidationResult.json'),'utf8'));
Object.assign(result,{generatedAt:new Date().toISOString(),runtimeEvidence:{...evidence,
  capture:{path:file,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex')}},
  visualFidelityChecks:[{checkId:'translation-history-bubbles',routeId:'v64HistoryDetail',region:'header/bilingual bubbles',status:'pass',
    evidence:[file],reason:'Screenshot inspected: fixed-design colors, bubble alignment, original/translated order. No full-app or pixel-identical claim.'}],
  majorIssues:['录音播放/下载保存仍按用户要求后置；统一页完整回执另批处理'],
  minorIssues:['iOS与真实账号未在线验收'],shouldSelfFix:false,
  stopReason:'read-only-history-scope-verified; proceed to settings; full-app score not assigned'});
fs.writeFileSync(path.join(dir,'AutoValidationResult.json'),JSON.stringify(result,null,2)+'\n');
