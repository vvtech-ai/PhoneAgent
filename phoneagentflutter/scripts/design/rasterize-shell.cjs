// Convert the original filtered SVG (not a page screenshot) losslessly to a
// 3x PNG for Flutter's unsupported CSS/filter elements. Keep the source SVG.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {chromium}=require('playwright');
const {pathToFileURL}=require('node:url');
async function main(){
  const root=path.resolve(__dirname,'../..');
  const source='assets/images/shell/shell_1.svg',target='assets/images/shell/home_voice_orb.png';
  const browser=await chromium.launch({channel:'chrome',headless:true});
  try {
    const page=await browser.newPage({viewport:{width:336,height:336}});
    await page.goto(pathToFileURL(path.join(root,source)).href);
    await page.locator('svg').evaluate(svg=>{svg.setAttribute('width','336');svg.setAttribute('height','336');});
    await page.locator('svg').screenshot({path:path.join(root,target),omitBackground:true});
  } finally {await browser.close();}
  const file=path.join(root,'design/home-model/updated-AssetManifest.json');
  const manifest=JSON.parse(fs.readFileSync(file,'utf8'));
  const bytes=fs.readFileSync(path.join(root,target));
  manifest.assets=manifest.assets.filter(a=>a.assetId!=='home_voice_orb_png');
  manifest.assets.push({...manifest.assets.find(a=>a.assetId==='shell_1'),assetId:'home_voice_orb_png',
    name:'home_voice_orb',format:'png',localPath:target,targetPath:target,
    hash:crypto.createHash('sha256').update(bytes).digest('hex'),derivedFrom:'shell_1',
    transformation:'original SVG CSS/filter rasterized with Chromium at 3x; no redesign'});
  fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');
  console.log('Original SVG converted to 336x336 PNG; hash recorded.');
}
main().catch(e=>{console.error(e);process.exitCode=1});
