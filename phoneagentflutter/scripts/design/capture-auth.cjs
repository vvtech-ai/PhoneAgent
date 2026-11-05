// Offline, fixed-commit HTML runtime capture. Does not call business APIs.
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const crypto = require('node:crypto');
const {chromium} = require('playwright');

async function main() {
  const root = path.resolve(__dirname, '../..');
  const source = path.join(root, '.local/design-auth/source/memory');
  const output = path.join(root, 'design/auth');
  const previews = path.join(root, '.local/design-auth/previews');
  fs.mkdirSync(output, {recursive: true});
  fs.mkdirSync(previews, {recursive: true});
  const stamp = {schemaVersion: '1.0', generatedAt: new Date().toISOString()};
  const write = (name, value) => fs.writeFileSync(path.join(output, name),
    JSON.stringify({...stamp, ...value}, null, 2) + '\n');
  const browser = await chromium.launch({channel: 'chrome', headless: true});
  try {
    const page = await browser.newPage({viewport: {width: 390, height: 844}});
    await page.route(/^https?:/, route => route.abort());
    const warnings = [];
    page.on('pageerror', e => warnings.push(e.message));
    await page.goto(pathToFileURL(path.join(source, 'index.html')).href);
    await page.evaluate(() => document.fonts.ready);
    const pages = [];
    for (const route of ['login', 'activation']) {
      await page.evaluate(name => window.showPage(name), route);
      await page.locator(`#${route}Page`).waitFor({state: 'visible'});
      await page.evaluate(async () => {
        await Promise.all(document.getAnimations().filter(a =>
          Number.isFinite(a.effect.getComputedTiming().endTime))
          .map(a => a.finished.catch(() => {})));
      });
      await page.locator(`#${route}Page img`).evaluateAll(async imgs => {
        await Promise.all(imgs.map(img => img.decode()));
      });
      pages.push(await page.evaluate(route => {
        const root = document.querySelector(`#${route}Page`);
        const rect = el => {
          const b = el.getBoundingClientRect();
          return {x: b.x, y: b.y, width: b.width, height: b.height};
        };
        const fields = ['display','position','flexDirection','justifyContent',
          'alignItems','gap','paddingTop','paddingRight','paddingBottom',
          'paddingLeft','marginTop','marginBottom','minHeight','maxWidth',
          'color','backgroundColor','backgroundImage','fontFamily','fontSize',
          'fontWeight','lineHeight','letterSpacing','border','borderRadius',
          'boxShadow','overflow','opacity','transform','zIndex','objectFit',
          'clipPath','maskImage','webkitMaskImage'];
        const visit = (el, key) => {
          const computed = getComputedStyle(el);
          const style = Object.fromEntries(fields.map(k => [k, computed[k]]));
          const id = el.id || key;
          return {id, sourceNodeId: id, name: el.id || el.className || el.tagName,
            type: el === root ? 'page' : el.tagName === 'IMG' ? 'image' :
              el.tagName === 'INPUT' ? 'input' : 'frame',
            sourceKind: 'runtime_dom', tagName: el.tagName,
            className: el.className, bounds: rect(el), style,
            layout: {mode: computed.display === 'flex' ?
              (computed.flexDirection === 'column' ? 'vertical' : 'horizontal') : 'stack'},
            text: {content: [...el.childNodes].filter(n => n.nodeType === 3)
              .map(n => n.textContent).join('').trim(),
              fontFamily: computed.fontFamily, fontSize: parseFloat(computed.fontSize),
              fontWeight: computed.fontWeight, lineHeight: computed.lineHeight},
            placeholder: el.getAttribute('placeholder'),
            assetRefs: el.tagName === 'IMG' ? ['authBrandLogo'] : [],
            image: el.tagName === 'IMG' ? {src: el.getAttribute('src'),
              width: el.naturalWidth, height: el.naturalHeight} : null,
            pseudo: Object.fromEntries(['::before','::after'].map(p =>
              [p, {content: getComputedStyle(el,p).content,
                backgroundImage: getComputedStyle(el,p).backgroundImage}])),
            children: [...el.children].filter(c => getComputedStyle(c).display !== 'none')
              .map((c,i) => visit(c, `${id}.${c.tagName.toLowerCase()}${i}`))};
        };
        return {...visit(root, root.id), appBounds: rect(document.querySelector('#appRoot')),
          systemInsets: {top: rect(document.querySelector('.status-bar')).height,
            bottom: 0, left: 0, right: 0}};
      }, route));
      await page.locator(`#${route}Page`).screenshot({path: path.join(previews, route + '.png')});
    }
    const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
    const resource = path.join(source, 'chakenailogo.png');
    write('SourceSnapshot.json', {sourceType: 'html', sourceId: 'phoneagent-auth',
      sourceUrl: 'memory/index.html', sourceVersion: '0cd58de9bb578845517aeb54bef8ab6970392b81',
      nodeIds: ['loginPage','activationPage'], fileKey: null, warnings,
      rawMetadata: {htmlRuntimeCapture: {engine: 'chromium', viewport: {width:390,height:844},
        routeSetup: 'existing showPage routing function', externalNetwork: 'blocked',
        previews: '.local/design-auth/previews', htmlSha256: hash(path.join(source, 'index.html'))},
        excludedSystemNodes: [{sourceNodeId: '.status-bar',systemRole:'statusBar',
          excludeReason:'由真实平台提供，不重绘原型 9:41',appliesToRoutes:['loginPage','activationPage']}],
        systemInsetsByPage: Object.fromEntries(pages.map(p=>[p.id,p.systemInsets]))}});
    write('DesignTree.json', {sourceSnapshotId: 'phoneagent-auth', pages, assets:['authBrandLogo']});
    write('AssetManifest.json', {source:'html', metrics: {pagePreviewCount:2,imageFillCount:2,
      vectorCandidateCount:0,exportSettingCount:0,instanceAssetCandidateCount:0,
      fontCandidateCount:0,nonPreviewAssetCount:1,excludedFoundationCount:0,excludedSystemNodeCount:1},
      assets:[{assetId:'authBrandLogo',sourceNodeId:'loginPage.div0.div0.img0',
        name:'auth_brand_logo',type:'image',format:'png',source:'html',sourceKind:'html_resource',
        role:'ui',resourceUrl:'.local/design-auth/source/memory/chakenailogo.png',
        urlStatus:'resolved',resolutionPlan:'fixed git archive',
        localPath:'.local/design-auth/source/memory/chakenailogo.png',
        targetPath:'assets/images/auth_brand_logo.png',hash:hash(resource),expiresAt:null,
        usage:['loginPage','activationPage'],downloadStatus:'downloaded',convertStatus:'not-needed'}]});
    console.log(JSON.stringify({warnings, pages:pages.map(p=>({id:p.id,bounds:p.bounds,
      container:p.children[0].bounds,children:p.children[0].children.map(n=>({name:n.name,bounds:n.bounds,style:n.style}))}))},null,2));
  } finally { await browser.close(); }
}
main().catch(error => { console.error(error); process.exitCode=1; });
