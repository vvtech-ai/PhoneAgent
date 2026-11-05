// Fixed HTML runtime evidence. No business traffic or user data.
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const crypto = require('node:crypto');
const {chromium} = require('playwright');
async function main() {
  const root = path.resolve(__dirname, '../..');
  const source = path.join(root, '.local/design-auth/source/memory');
  const conversation = process.argv.includes('--conversation');
  const translation = process.argv.includes('--translation');
  const identity = process.argv.includes('--identity');
  const feature = identity ? 'identity' : translation ? 'translation-history' : conversation ? 'conversation-history' : 'home-model';
  const output = path.join(root, 'design', feature);
  const previews = path.join(root, '.local', 'design-'+feature, 'previews');
  fs.mkdirSync(output, {recursive:true}); fs.mkdirSync(previews,{recursive:true});
  const stamp = {schemaVersion:'1.0',generatedAt:new Date().toISOString()};
  const write = (name,value) => fs.writeFileSync(path.join(output,name),
    JSON.stringify({...stamp,...value},null,2)+'\n');
  const browser = await chromium.launch({channel:'chrome',headless:true});
  try {
    const page = await browser.newPage({viewport:{width:390,height:844}});
    await page.route(/^https?:/,route=>route.abort());
    const sourceUrl=pathToFileURL(path.join(source,'index.html')).href+(identity?'?qa=v63':'');
    await page.goto(sourceUrl);
    await page.evaluate(()=>document.fonts.ready);
    const pages=[]; const resources=new Map();
    for (const route of (identity ? ['empty','filled','verified','edit','delete'] : translation ? ['v64HistoryDetail'] : conversation ? ['tasks','pureVoice'] : ['home','voiceModel','voiceIdentity'])) {
      if(identity) {
        await page.goto(sourceUrl);
        await page.evaluate(state=>{
          window.V63QA.set({identity:{status:state==='empty'?'empty':state==='filled'?'filled':'verified',name:state==='empty'?'':'测试姓名',mobile:'',gender:'undisclosed'}});
          window.V63QA.openIdentity();
        },route);
        if(route==='edit')await page.locator('#v63EditIdentity').click();
        if(route==='delete')await page.locator('#v63DeleteIdentity').click();
      }
      else if(translation) {await page.evaluate(()=>{window.showPage('tasks');window.V64TranslationHistory.open();});}
      else await page.evaluate(name=>window.showPage(name),route);
      const selector = identity ? (route==='delete'?'#v63Overlay':'#myIdentityPage') : translation ? '#v64HistoryDetail' : `#${route}Page`;
      await page.locator(selector).waitFor({state:'visible'});
      await page.waitForTimeout(route === 'home' ? 3500 : 500);
      const captured=await page.evaluate(selector=>{
        const rect=e=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height}};
        const vector=e=>{if(e.tagName.toLowerCase()!=='svg')return null;
          const copy=e.cloneNode(true),a=[e,...e.querySelectorAll('*')],b=[copy,...copy.querySelectorAll('*')];
          a.forEach((node,i)=>{const style=getComputedStyle(node);for(const key of ['fill','stroke','stroke-width','stroke-linecap','stroke-linejoin'])
            b[i].setAttribute(key,style.getPropertyValue(key));});return copy.outerHTML;};
        const fields=['display','flexDirection','gap','padding','margin','color','backgroundColor',
          'backgroundImage','fontSize','fontWeight','lineHeight','border','borderRadius','boxShadow',
          'opacity','maskImage','webkitMaskImage','gridTemplateColumns'];
        const visit=(e,id)=>{const s=getComputedStyle(e);return {id:e.id||id,sourceNodeId:e.id||id,
          name:e.id||e.getAttribute('class')||e.tagName,type:e.tagName==='IMG'?'image':'frame',tagName:e.tagName,
          bounds:rect(e),style:Object.fromEntries(fields.map(k=>[k,s[k]])),
          text:{content:[...e.childNodes].filter(n=>n.nodeType===3).map(n=>n.textContent).join('').trim()},
          image:e.tagName==='IMG'?{src:e.getAttribute('src'),complete:e.complete&&e.naturalWidth>0}:null,
          vector:vector(e),
          pseudo:Object.fromEntries(['::before','::after'].map(p=>[p,
            Object.fromEntries(['content','backgroundImage','maskImage','opacity','width','height','right','bottom']
              .map(k=>[k,getComputedStyle(e,p)[k]]))])),
          children:[...e.children].filter(c=>getComputedStyle(c).display!=='none')
            .map((c,i)=>visit(c,`${id}.${i}`))};};
        const e=document.querySelector(selector);
        return {...visit(e,e.id),type:'page',navigation:selector==='#homePage'?
          visit(document.querySelector('#floatingNav'),'tabbar'):null};
      },selector);
      if(identity){captured.id='identity-'+route;captured.sourceNodeId='identity-'+route;}
      pages.push(captured);
      await page.screenshot({path:path.join(previews,route+'.png')});
    }
    const hash=data=>crypto.createHash('sha256').update(data).digest('hex');
    function assets(n) {
      if(n.image) resources.set(n.image.src,{node:n.id,src:n.image.src});
      if(n.vector) resources.set(n.id,{node:n.id,svg:n.vector});
      n.children.forEach(assets); if(n.navigation)assets(n.navigation);
    }
    pages.forEach(assets);
    function cssAssets(n){for(const pseudo of Object.values(n.pseudo||{})) {
      const match=pseudo.backgroundImage?.match(/^url\("(.*)"\)$/);
      if(match&&match[1].startsWith('file:'))resources.set(match[1],{node:n.id,
        src:require('node:url').fileURLToPath(match[1]),kind:'html_css_background'});
    } n.children.forEach(cssAssets);}
    pages.forEach(cssAssets);
    const assetList=[];
    for(const [key,r] of resources) {
      const id=(identity ? 'identity_' : translation ? 'translation_' : conversation ? 'conversation_' : 'shell_')+assetList.length;
      const local=r.src?path.resolve(source,r.src):null;
      const bytes=r.svg?Buffer.from(r.svg):local&&fs.existsSync(local)?fs.readFileSync(local):null;
      const format=r.svg?'svg':path.extname(r.src).slice(1);
      const target=`assets/images/${identity ? 'identity' : translation ? 'translation' : conversation ? 'conversation' : 'shell'}/${id}.${format}`;
      if(bytes){fs.mkdirSync(path.dirname(path.join(root,target)),{recursive:true});fs.writeFileSync(path.join(root,target),bytes);}
      assetList.push({assetId:id,sourceNodeId:r.node,name:id,type:r.svg?'svg':'image',
        format,source:'html',sourceKind:r.svg?'inline_svg':'html_resource',role:'ui',
        usage:[r.node],downloadStatus:'downloaded',convertStatus:'not-needed',
        resourceUrl:r.src||key,urlStatus:bytes?'resolved':'unresolved',
        resolutionPlan:bytes?'fixed commit bytes':'inspect missing source; no placeholder substitution',
        localPath:bytes?target:null,targetPath:target,hash:bytes?hash(bytes):null});
    }
    write('SourceSnapshot.json',{sourceType:'html',sourceId:'phoneagent-'+feature,
      sourceUrl:'memory/index.html',sourceVersion:'0cd58de9bb578845517aeb54bef8ab6970392b81',
      nodeIds:pages.map(p=>p.id),warnings:[],rawMetadata:{viewport:{width:390,height:844},externalNetwork:'blocked',
        htmlSha256:hash(fs.readFileSync(path.join(source,'index.html'))),
        excluded:['prototype status bar','old inline composer','future custom models','recharge']}});
    write('DesignTree.json',{sourceSnapshotId:'phoneagent-'+feature,pages,assets:assetList.map(a=>a.assetId)});
    write('AssetManifest.json',{source:'html',assets:assetList});
    console.log(JSON.stringify({pages:pages.map(p=>p.id),assets:assetList.length,
      unresolved:assetList.filter(a=>a.urlStatus!=='resolved').map(a=>a.resourceUrl)}));
  } finally {await browser.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1});
