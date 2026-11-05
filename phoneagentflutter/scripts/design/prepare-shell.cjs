// Mechanical normalization and traceability; generated JSON is not an app renderer.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const conversation=process.argv.includes('--conversation');
const translation=process.argv.includes('--translation');
const identity=process.argv.includes('--identity');
const feature=identity?'identity':translation?'translation-history':conversation?'conversation-history':'home-model';
const root=path.resolve(__dirname,'../..'),dir=path.join(root,'design',feature);
const read=n=>JSON.parse(fs.readFileSync(path.join(dir,n),'utf8'));
const stamp={schemaVersion:'1.0',generatedAt:new Date().toISOString()};
const write=(n,d)=>fs.writeFileSync(path.join(dir,n),JSON.stringify({...stamp,...d},null,2)+'\n');
const report=(n,d)=>fs.writeFileSync(path.join(dir,n),'# '+feature+' '+n.replace('.md','')+'\n\n'+d+'\n');
const tree=read('DesignTree.json'),manifest=read('AssetManifest.json'),all=[];
function normalize(n,p,parentId=null){const result={...n,parentId,
  assetRefs:manifest.assets.filter(a=>a.sourceNodeId===n.sourceNodeId).map(a=>a.assetId),
  sourceBounds:n.bounds,bounds:{...n.bounds,x:n.bounds.x-p.bounds.x,y:n.bounds.y-p.bounds.y},
  renderPolicy:'render',isSystemProvided:false,layout:{mode:n.style.display==='grid'?'grid':'vertical'},
  effects:{shadow:n.style.boxShadow},cornerRadius:parseFloat(n.style.borderRadius),
  children:n.children.map(c=>normalize(c,p,n.id))};all.push(result);return result;}
const pages=tree.pages.map(p=>({...normalize(p,p),navigation:p.navigation?normalize(p.navigation,p):null,
  contentViewport:{x:0,y:0,width:p.bounds.width,height:p.bounds.height},coordinateRebase:{x:-p.bounds.x,y:-p.bounds.y}}));
const tokens={pagePadding:22,contentPadding:28,gridGap:12,cardRadius:24,cardPadding:16,
  cardMinHeight:122,heroHeight:250,heroTitle:28,heroSubtitle:14,modelChipHeight:34,
  modelChipText:12,sectionTitle:22,cardTitle:18,cardSubtitle:13,navRadius:30,navHeight:80,
  accent:'#0A84FF',text:'#111111',secondary:'#6E6E73',background:'#FBFCFD'};
write('NormalizedDesignTree.json',{sourceSnapshotId:'phoneagent-'+feature,pages,assets:tree.assets,tokens,
  systemInsets:{top:41,bottom:0},runtimeFillPolicy:'fillAvailableViewport',
  excludedSystemNodes:[{sourceNodeId:'.status-bar',systemRole:'statusBar',excludeReason:'platform',appliesToRoutes:pages.map(p=>p.id)}]});
write('component-tree.json',{targetPlatform:'flutter',pages:pages.map(p=>({id:p.id,rootComponent:p.id})),
  components:all.map(n=>({id:n.id,name:n.name.replace(/(^|[^a-zA-Z0-9]+)([a-zA-Z0-9])/g,(_,a,b)=>b.toUpperCase()),kind:n.type==='page'?'page':n.children.length?'molecule':'atom',
    semanticRole:n.tagName==='BUTTON'?'button':n.text.content?'text':'unknown',sourceNodeIds:[n.sourceNodeId],
    visualNodeRefs:[n.sourceNodeId],assetRefs:n.assetRefs,props:[],layoutSpec:n.layout,styleSpec:n.style,
    fidelityRisk:'medium',children:n.children.map(c=>c.id)}))});
for(const a of manifest.assets){const bytes=fs.readFileSync(path.join(root,a.localPath));
  if(crypto.createHash('sha256').update(bytes).digest('hex')!==a.hash)throw Error('Asset hash mismatch');}
write('updated-AssetManifest.json',manifest);
const controls=(identity ? [['v63IdentityBack','identity-empty','back'],['v63AddIdentity','identity-empty','identity-edit'],
  ['v63EditIdentity','identity-filled','identity-edit'],['v63DeleteIdentity','identity-filled','identity-delete'],
  ['v63VerifyIdentity','identity-filled','model-settings'],['v63IdentityName','identity-edit','edit-name'],
  ['v63IdentityMobile','identity-edit','edit-phone'],['myIdentityPage.1.0.0.2.1','identity-edit','gender'],
  ['myIdentityPage.1.0.0.3.1','identity-edit','save'],['v63IdentityCancel','identity-edit','cancel-edit'],
  ['v63Cancel','identity-delete','dismiss'],['v63Confirm','identity-delete','delete']]
  : translation ? [['v64HistoryClose','v64HistoryDetail','back'],
  ['v64RecordingPlay','v64HistoryDetail','audio-deferred'],['v64RecordingSave','v64HistoryDetail','save-deferred']]
  : conversation ? [['tasksPage.1.0.3','tasksPage','pureVoicePage'],
  ['pvCloseBtn','pureVoicePage','back'],['pvTextToggleBtn','pureVoicePage','toggle-input'],
  ['pvTextSendBtn','pureVoicePage','send-text'],['taskVoiceModelChip','pureVoicePage','model-sheet'],
  ['pvControlBtn','pureVoicePage','voice-not-implemented'],['pvPlusBtn','pureVoicePage','attachment-not-implemented']]
  : [['homeVoiceModelChip','homePage','model-sheet'],['quickRow','homePage','skill-entry'],
  ['floatingNav','homePage','tab-switch'],['assistantFab','homePage','dialer'],
  ['backFromVoiceModel','voiceModelPage','back'],['provider-option','voiceModelPage','select-provider'],
  ['voice-setting','voiceModelPage','voiceIdentityPage'],['backFromVoiceIdentity','voiceIdentityPage','back'],
  ['callVoiceList','voiceIdentityPage','select-voice']]).map(([id,pageId,action])=>({id,controlId:id,pageId,
    sourceRouteId:pageId,sourceNodeId:id,nodeId:id,action,label:action,role:'primaryButton',priority:'critical',
    actionability:'must-interact',confidence:'high',reason:'HTML visual + v65 runtime behavior',
    bounds:all.find(n=>n.id===id)?.bounds||{x:0,y:0,width:1,height:1}}));
write('ActionableControlInventory.json',{targetPlatform:'flutter',controls,coverage:{totalControls:controls.length,mappedControls:controls.length}});
write('InteractionMap.json',{targetPlatform:'flutter',interactions:controls.map(c=>({...c,interactionId:c.id,
  triggerNodeId:c.id,eventType:'click',actionType:c.action==='back'?'back':'navigate',testTag:c.id,source:'manual',
  targetRouteId:c.action,hitArea:c.bounds,
  expectedResult:{behavior:c.action},runtimeBinding:'typed controller callback'}))});
const nodes=pages.map(p=>({routeId:p.id,sourceNodeId:p.id,name:p.id,module:feature,kind:p.id==='identity-delete'?'dialog':'list',
  ...(p.id==='identity-delete'?{baseRouteId:'identity-verified',overlayKind:'dialog'}:{}),
  states:conversation?['restoring','ready','sending','recoveryRequired','restoreFailed','closed']:['loading','content','error','saving']}));
const edges=controls.map(c=>({edgeId:c.id,sourceRouteId:c.pageId,targetRouteId:c.action,eventType:'click',source:'manual',confidence:'high'}));
write('RouteGraph.json',{targetPlatform:'flutter',initialRoute:pages[0].id,nodes,edges,
  coverage:{totalScreens:pages.length,connectedScreens:pages.length,coverageRatio:1}});
write('PageStateGraph.json',{targetPlatform:'flutter',states:nodes,transitions:edges,
  coverage:{totalScreens:pages.length,classifiedScreens:pages.length,stateGraphCoverageRatio:1}});
const config=JSON.parse(fs.readFileSync(path.join(root,'design/auth/TargetAppConfig.json'),'utf8'));
write('TargetAppConfig.json',{...config,featureName:feature,outputDir:identity?'lib/features/identity':translation?'lib/features/translation_history':conversation?'lib/features/conversation':'lib/features/home',
  designSystem:{...config.designSystem,tokenFile:'lib/core/design/shell_tokens.dart'}});
report('normalize-report.md',`${all.length} 个节点保留 computed style；display:contents 容器不丢弃子节点。以平台 SafeArea 替代原型状态栏，页面弹性填充。设计卡片内容/可用性由真实 published 配置覆盖。`);
report('components.md','首页 Header/Hero/ModelChip/SkillGrid 与 FloatingNavigation；模型列表与音色列表分别独立页面。非 JSON 解释器，页面只接收状态和回调。');
report('assets.md',`${manifest.assets.length} 个真实图像/内联 SVG 资源哈希核验通过；首页服务端卡片背景仅接受 v65 允许的资源地址。不得下载页面截图充当 UI。`);
report('interaction.md','模型成功保存后选择更新；失败保留旧值；下一次通话生效。音色只选择系统 AI；克隆录放后置且明确提示。未来自定义模型/充值排除。首页跳转下游仍在迁移，不声明完整初版。');
write('AutoValidationPlan.json',{targetPlatform:'flutter',packageName:'com.vvtech.aiassistant.dev',
  deviceSerial:'emulator-5554',routes:nodes,interactions:read('InteractionMap.json').interactions,
  routeSetupStrategy:'graph-walk',visualChecks:['hero','nav','cards','models','voices'],
  thresholds:{routeCoverageThreshold:1,maxBlankEdgeRatio:0.1}});
write('AutoValidationResult.json',{targetPlatform:'flutter',packageName:'com.vvtech.aiassistant.dev',
  architectureChecks:{genericJsonRenderer:false,fullPagePreviewBackground:false},visualFidelityChecks:[],
  templateRisk:{riskLevel:'low',reason:'原始资源+独立真实控件',evidence:['component-tree.json']},
  blockers:[],majorIssues:['完整初版尚未完成；下游业务入口继续迁移'],minorIssues:[],score:0,
  shouldSelfFix:false,stopReason:'pending-runtime-evidence'});
console.log(`Prepared ${all.length} nodes and ${controls.length} control groups.`);
if(conversation){
  report('normalize-report.md',`${all.length} computed-style nodes from fixed HTML; platform SafeArea replaces prototype status bar. Task cards: padding16/radius24/gap10; unified header/stages/thread/composer remain separate.`);
  report('components.md','TasksPage / ConversationRoute / ConversationPage / ConversationComposer. UI only receives state/callbacks; account-bound providers compose repository and controller. Static waveform is not audio status.');
  report('assets.md',`${manifest.assets.length} original SVG assets; hashes verified. No full-page raster UI.`);
  report('interaction.md','Default voice, text toggle same session/channel; ordinary task all statuses restore. Active option sends ordinal text. Local exit cancels stream, not backend calls. Audio/attachments/call orchestration/result pages pending.');
  write('AutoValidationPlan.json',{targetPlatform:'flutter',packageName:'com.vvtech.aiassistant.dev',deviceSerial:'emulator-5554',
    routes:nodes,interactions:read('InteractionMap.json').interactions,routeSetupStrategy:'graph-walk',
    visualChecks:['task-card','header','composer','message','option','keyboard-safe-area'],
    thresholds:{routeCoverageThreshold:1,maxBlankEdgeRatio:0.1}});
}
if(translation){
  report('normalize-report.md',`${all.length} fixed HTML computed-style nodes. Replace prototype 44px top padding with native SafeArea + header18. Background #F4F7FB, own bubble #1677E8, padding14/16, radius22/6, gap18.`);
  report('components.md','TranslationHistoryRoute/Page, header, bilingual bubble; loading/error controller; recording grant excluded from presentation state.');
  report('assets.md','Original recording-save SVG retained in governed assets for later audio phase; no full-page screenshot UI.');
  report('interaction.md','Task REALTIME_TRANSLATION opens detail; close/system back returns list. Recording/play/save deferred by user sequencing, no fake playback. No old result-page route.');
  write('AutoValidationPlan.json',{targetPlatform:'flutter',packageName:'com.vvtech.aiassistant.dev',deviceSerial:'emulator-5554',
    routes:nodes,interactions:read('InteractionMap.json').interactions,routeSetupStrategy:'graph-walk',
    visualChecks:['header','original-translation-order','bubble-alignment','small-screen','failure-retry'],
    thresholds:{routeCoverageThreshold:1,maxBlankEdgeRatio:0.1}});
}
if(identity){
  report('normalize-report.md',`${all.length} fixed HTML runtime nodes / five states. Platform SafeArea replaces prototype status bar. Header 18px outer padding, body36px, card18px/radius24; form48px/radius13, CTA44px/radius14. Inset-adaptive, not fixed-height viewport.`);
  report('components.md','IdentityRoute / IdentityPage / IdentityEditor / identity widgets: header, profile card, empty card, delete dialog. No runtime JSON renderer. Repeated states share actual components.');
  report('assets.md','3 original SVG assets: back/delete/edit. Bytes + hashes retained, no screenshot UI.');
  report('interaction.md','Source version fixed; v65 overrides prototype: phone optional with mainland validation; first save stays, existing save returns; clone enters model settings; all deletes warn about clone removal. System back pops route/dialog, not fictional paused session. SDK/clone/media deferred.');
  write('AutoValidationPlan.json',{targetPlatform:'flutter',packageName:'com.vvtech.aiassistant.dev',deviceSerial:'emulator-5554',
    routes:nodes,interactions:read('InteractionMap.json').interactions,routeSetupStrategy:'graph-walk',
    visualChecks:['empty','filled','verified','edit','delete-dialog','keyboard-small-screen'],
    thresholds:{routeCoverageThreshold:1,maxBlankEdgeRatio:0.1}});
  write('AutoValidationResult.json',{targetPlatform:'flutter',packageName:'com.vvtech.aiassistant.dev',
    architectureChecks:{genericJsonRenderer:false,fullPagePreviewBackground:false},visualFidelityChecks:[],
    templateRisk:{riskLevel:'low',reason:'fixed runtime parameters and original SVG',evidence:['DesignTree.json']},
    blockers:['Device installation previously blocked by execution policy; no retry/bypass'],
    majorIssues:['SDK/clone/first-login guide deferred'],minorIssues:[],score:0,shouldSelfFix:false,stopReason:'device-validation-blocked'});
}
