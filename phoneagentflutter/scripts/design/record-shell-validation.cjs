// Record completed checks only; online account APIs and full-app acceptance stay open.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),dir=path.join(root,'design/home-model');
const evidence=JSON.parse(fs.readFileSync(path.join(root,'.local/home-model-validation/result.json'),'utf8'));
const captures=['home','models-sheet','models-page','voices-page'].map(id=>{
  const file=`.local/home-model-validation/${id}.png`;
  return {id,path:file,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex')};
});
const result=JSON.parse(fs.readFileSync(path.join(dir,'AutoValidationResult.json'),'utf8'));
Object.assign(result,{generatedAt:new Date().toISOString(),screenshots:captures,
  buildResults:[{command:'flutter analyze',status:'pass'}, {command:'flutter test',status:'pass',tests:90},
    {command:'flutter build apk --debug (configured test environment)',status:'pass'}],
  interactionResults:[{status:'pass',evidence:'.local/home-model-validation/result.json',...evidence}],
  visualFidelityChecks:[{checkId:'home-model-readability',routeId:'homePage',region:'header / grid / navigation',
    status:'pass',evidence:captures.map(c=>c.path),reason:'Device screenshots inspected; native assets and controls, no overflow. Not a pixel-identical or full-app acceptance claim.'}],
  minorIssues:['平台字体允许差异；未声明逐像素一致','公开首页在线通过，真实账号模型/音色未完成在线验收'],
  shouldSelfFix:false,stopReason:'scoped-milestone-verified; continue next feature; score not assigned to incomplete app'});
fs.writeFileSync(path.join(dir,'AutoValidationResult.json'),JSON.stringify(result,null,2)+'\n');
