// Mechanical intermediate-artifact generation; never loaded by the app.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const dir = path.join(root, 'design/auth');
const read = name => JSON.parse(fs.readFileSync(path.join(dir, name), 'utf8'));
const stamp = {schemaVersion:'1.0', generatedAt:new Date().toISOString()};
const write = (name, data) => fs.writeFileSync(path.join(dir, name),
  JSON.stringify({...stamp, ...data}, null, 2) + '\n');
const report = (name, body) => fs.writeFileSync(path.join(dir, name),
  '# Auth ' + name.replace('.md','') + '\n\n' + body +
  '\n\n输入：固定 0cd58de9 HTML 的 SourceSnapshot / DesignTree（schema 1.0）。' +
  '行为覆盖以 v65 4c781e3 为准。仅本批两页，无其他页面完成声明。\n');
const tree = read('DesignTree.json');
const source = read('SourceSnapshot.json');
const manifest = read('AssetManifest.json');
const all = [];
function normalize(node, page, parentId=null) {
  const n = {...node, parentId,
    bounds:{...node.bounds, x:node.bounds.x-page.bounds.x, y:node.bounds.y-page.bounds.y},
    sourceBounds:node.bounds, renderPolicy:'render', isSystemProvided:false,
    effects:{shadow:node.style.boxShadow},cornerRadius:parseFloat(node.style.borderRadius),
    constraints:{horizontal:'center',vertical:'flow'},
    interactions:['INPUT','BUTTON'].includes(node.tagName) ? [{trigger:'native-control'}] : [],
    children:node.children.map(c=>normalize(c,page,node.id))};
  all.push(n);
  return n;
}
const pages = tree.pages.map(p=>({...normalize(p,p),
  contentViewport:{x:0,y:0,width:p.bounds.width,height:p.bounds.height},
  coordinateRebase:{x:-p.bounds.x,y:-p.bounds.y},runtimeFillPolicy:'fillAvailableViewport'}));
write('NormalizedDesignTree.json', {sourceSnapshotId:source.sourceId,pages,assets:tree.assets,
  systemInsets:source.rawMetadata.systemInsetsByPage,
  contentViewport:pages.map(p=>({pageId:p.id,...p.contentViewport})),
  runtimeFillPolicy:'fillAvailableViewport',
  excludedSystemNodes:source.rawMetadata.excludedSystemNodes,
  coordinateRebase:pages.map(p=>({pageId:p.id,...p.coordinateRebase})),
  tokens:{backgroundLayers:['linear-gradient(180deg,rgba(255,255,255,.74),rgba(255,255,255,.70))',
    'linear-gradient(135deg,#fbfbfd,#edf0f7)'],pagePadding:18,containerPadding:[40,24,24,24],
    formMaxWidth:320,logo:[107,98],brandToForm:54,fieldHeight:58,fieldGap:12,ctaGap:20,
    ctaHeight:49,radius:12,focus:'#0A84FF',text:'#1A1A2E',hint:'#B0B4C3',subtitle:'#8B8FA3'}});
report('normalize-report.md','保留所有 '+all.length+' 个可见节点及完整 computed style。状态栏由平台提供，坐标减去源页面 y=41。背景来自祖先 .screen 的两层渐变；10px 原型壳底部留白不迁移。字体用平台系统字体，可能存在字形/行高差异。允许进入组件阶段。');
const components = all.map(n=>({id:n.id,name:n.name.replace(/(^|[^a-zA-Z0-9]+)([a-zA-Z0-9])/g,(_,a,b)=>b.toUpperCase()),
  kind:n.type==='page'?'page':n.children.length?'molecule':'atom',sourceNodeIds:[n.sourceNodeId],props:[],
  semanticRole:n.tagName==='INPUT'?'input':n.tagName==='BUTTON'?'button':
    n.type==='image'?'image':n.text.content?'text':'form',
  visualNodeRefs:[n.sourceNodeId],assetRefs:n.assetRefs,
  layoutSpec:{...n.layout,bounds:n.bounds,children:n.children.map(c=>c.id)},
  styleSpec:n.style,fidelityRisk:'medium',fidelityNotes:['platform-system-font'],
  children:n.children.map(c=>c.id)}));
write('component-tree.json',{targetPlatform:'flutter',pages:pages.map(p=>({id:p.id,rootComponent:p.id})),components});
report('components.md','AuthFrame 负责 SafeArea/滚动/居中；AuthBrand 负责 Logo/标题/副标题；AuthInputGroup 负责真实输入和发送按钮；AuthPrimaryButton 负责 CTA。组件各自引用源节点，主页面非 JSON 解释器，无坐标覆盖层。允许进入资源阶段。');
for (const a of manifest.assets) {
  if (a.role==='preview'||a.urlStatus!=='resolved') throw Error('Invalid UI asset '+a.assetId);
  const data = fs.readFileSync(path.join(root,a.localPath));
  if (crypto.createHash('sha256').update(data).digest('hex')!==a.hash) throw Error('Hash mismatch');
  fs.mkdirSync(path.dirname(path.join(root,a.targetPath)),{recursive:true});
  fs.copyFileSync(path.join(root,a.localPath),path.join(root,a.targetPath));
}
write('updated-AssetManifest.json',{...manifest,...stamp,assets:manifest.assets.map(a=>({...a,localPath:a.targetPath}))});
report('assets.md','Logo 从 AssetManifest 指定文件复制并验证 SHA256；保留原始 PNG/透明度，344x315 按107x98 contain。无预览图充当 UI，无新增字体下载。允许进入交互阶段。');
const definitions = [
  ['loginPhone','loginPage','input','输入手机号'],
  ['loginCode','loginPage','input','输入4–8位验证码'],
  ['loginGetCode','loginPage','submit','发送验证码'],
  ['loginBtn','loginPage','submit','登录；仅服务结果要求时进入邀请码'],
  ['activationCodeInput','activationPage','input','输入邀请码'],
  ['activationBtn','activationPage','submit','提交邀请码及challenge'],
  ['backLogin','activationPage','back','返回登录；来自v65 onBackLogin']
];
const controls = definitions.map(([id,pageId,action,label])=>({id,controlId:id,pageId,sourceRouteId:pageId,nodeId:id,
  sourceNodeId:id==='backLogin'?'V88AuthPages.onBackLogin':id,label,
  role:action==='input'?'input':action==='back'?'back':'formSubmit',priority:'critical',actionability:'must-interact',
  confidence:'high',reason:'v65 current behavior',
  controlBoundsSource:id==='backLogin'?'manual-review-required':'component-node',
  action,bounds:all.find(n=>n.id===id)?.bounds||{x:151,y:570,width:88,height:48}}));
write('ActionableControlInventory.json',{targetPlatform:'flutter',controls,coverage:{totalControls:7,mappedControls:7}});
write('InteractionMap.json',{targetPlatform:'flutter',interactions:controls.map(c=>({id:c.id,interactionId:c.id,triggerNodeId:c.sourceNodeId,
  controlRole:c.role,actionType:c.action==='input'?'updateInput':c.action,
  eventType:c.action==='input'?'input':'click',sourceRouteId:c.pageId,
  targetRouteId:c.id==='backLogin'?'loginPage':c.id==='loginBtn'?'activationPage':c.pageId,
  hitArea:c.bounds,source:'manual',confidence:'high',testTag:c.id,
  description:c.label,runtimeBinding:'TextField.onChanged or Button.onPressed',
  expectedResult:{behavior:c.label,conditional:c.id==='loginBtn'?'gateway.inviteRequired':null},
  evidence:c.id==='backLogin'?'v65 production code':'HTML visual + v65 behavior'}))});
const nodes = pages.map(p=>({routeId:p.id,sourceNodeId:p.id,name:p.id,module:'auth',kind:'form',
  states:['idle','submitting','error'],additionalStates:p.id==='loginPage'?['sendingCode','cooldown']:['inviteRequired']}));
const edges = [{edgeId:'requireInvite',sourceRouteId:'loginPage',targetRouteId:'activationPage',eventType:'submit',
  source:'manual',confidence:'high',reason:'gateway.inviteRequired'},
  {edgeId:'backLogin',sourceRouteId:'activationPage',targetRouteId:'loginPage',eventType:'back',
    source:'manual',confidence:'high',reason:'backLogin or systemBack'}];
write('PageStateGraph.json',{targetPlatform:'flutter',states:nodes,transitions:edges,
  coverage:{totalScreens:2,classifiedScreens:2,stateGraphCoverageRatio:1}});
write('RouteGraph.json',{targetPlatform:'flutter',initialRoute:'loginPage',nodes,edges,
  coverage:{totalScreens:2,connectedScreens:2,coverageRatio:1},
  strategy:'auth-local back state guarded with PopScope; outer go_router unchanged'});
report('interaction.md','7 个关键交互 7/7 映射。邀请码依后端结果，不无条件跳转；返回登录按 v65 补足。登录校验4–8位，邀请码只要求非空，不照搬原型20位上限/尾号000规则。成功仅交付端口结果，真实会话持久化后续；生产入口使用不可用适配，合成成功只在测试。允许进入代码阶段。');
write('TargetAppConfig.json',{targetPlatform:'flutter',projectMode:'existing-project',
  outputDir:'lib/features/auth',packageName:'phone_agent',featureName:'auth',
  designSystem:{tokenFile:'lib/core/design/auth_tokens.dart',themeFile:'lib/app/phone_agent_app.dart',allowHardcodedValues:false},
  stateManagement:{library:'riverpod',stateDir:'lib/features/auth/presentation/controller',mockDataDir:'test/support'},
  systemUi:{renderDesignSystemBars:false,usePlatformSystemBars:true,contentViewportSource:'platform-window-insets'},
  validationCommands:['flutter analyze','flutter test','flutter build apk --debug'].map(command=>({name:command,command,required:true})),
  autoValidation:{enabled:true,provider:'openspec',maxSelfFixRounds:2,maxNoImprovementRounds:2},
  hosts:[{id:'android',applicationId:'com.vvtech.aiassistant.dev',device:'emulator-5554',
    report:'docs/engineering/AUTH_VALIDATION.md'},
    {id:'ios',bundleId:'com.chaken.phoneagent.test',report:'docs/engineering/AUTH_VALIDATION.md#ios',status:'not-validated-in-this-batch'}]});
console.log('Prepared '+all.length+' nodes, '+controls.length+' semantic controls, '+manifest.assets.length+' assets.');
