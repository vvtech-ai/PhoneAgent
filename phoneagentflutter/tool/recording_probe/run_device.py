#!/usr/bin/env python3
"""Opt-in isolated iPhone synthetic encoder test. No ordinary app writes or live audio."""
import pathlib,subprocess,plistlib,json,hashlib,shutil,datetime,argparse,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--device',required=True)
args=parser.parse_args()
def device_run(*command):
 return subprocess.run(['xcrun','devicectl','device',*command[:2],'--device',args.device,'--timeout','30',*command[2:]],check=True,capture_output=True)

out=ROOT/'.local/recording-device-probe';out.mkdir(parents=True,exist_ok=True);app=out/'RecordingDeviceProbe.app';app.mkdir(exist_ok=True)
device_run('info','details','--json-output',str(out/'device-details.json'))
device=json.loads((out/'device-details.json').read_text())['result'];udid=device['hardwareProperties']['udid']
profiles=list((pathlib.Path.home()/'Library/Developer/Xcode/UserData/Provisioning Profiles').glob('*.mobileprovision'))+list((pathlib.Path.home()/'Library/MobileDevice/Provisioning Profiles').glob('*.mobileprovision'))
profile=None
for p in profiles:
 r=subprocess.run(['security','cms','-D','-i',str(p)],capture_output=True)
 if r.returncode:continue
 d=plistlib.loads(r.stdout)
 if d.get('Entitlements',{}).get('application-identifier','').endswith('.*') and udid in d.get('ProvisionedDevices',[]) and d['ExpirationDate']>datetime.datetime.now():profile=(p,d);break
assert profile,'No existing eligible wildcard profile; no provisioning mutation attempted'
p,d=profile;team=d['TeamIdentifier'][0];bundle='com.vvtech.phoneagent.synthetic.recordingdeviceprobe'
identities=subprocess.check_output(['security','find-identity','-v','-p','codesigning'],text=True)
cert=next((hashlib.sha1(c).hexdigest().upper() for c in d['DeveloperCertificates'] if hashlib.sha1(c).hexdigest().upper() in identities),None);assert cert,'No existing signing identity'
engine=pathlib.Path('/Users/Eason/.cache/phoneagent-flutter-3.32.0/flutter/bin/cache/artifacts/engine/ios-profile/Flutter.xcframework/ios-arm64')
assert engine.exists()
frameworks=app/'Frameworks';frameworks.mkdir(exist_ok=True);shutil.copytree(engine/'Flutter.framework',frameworks/'Flutter.framework',dirs_exist_ok=True)
sdk=subprocess.check_output(['xcrun','--sdk','iphoneos','--show-sdk-path'],text=True).strip()
cmd=['xcrun','--sdk','iphoneos','swiftc','-sdk',sdk,'-target','arm64-apple-ios15.0','-F',str(engine),'-framework','Flutter','-Xlinker','-rpath','-Xlinker','@executable_path/Frameworks','-o',str(app/'RecordingDeviceProbe'),str(ROOT/'tool/recording_probe/ios/DeviceEncodingProbeHost.swift'),str(ROOT/'ios/Runner/DomesticRecordingChannel.swift')]
subprocess.run(cmd,check=True)
info={'CFBundleIdentifier':bundle,'CFBundleExecutable':'RecordingDeviceProbe','CFBundleName':'Synthetic Encoding Probe','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','CFBundlePackageType':'APPL','MinimumOSVersion':'15.0','LSRequiresIPhoneOS':True,'UIDeviceFamily':[1],'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait'],'UILaunchScreen':{}}
(app/'Info.plist').write_bytes(plistlib.dumps(info));shutil.copy2(p,app/'embedded.mobileprovision')
ent={'application-identifier':team+'.'+bundle,'com.apple.developer.team-identifier':team,'get-task-allow':d['Entitlements'].get('get-task-allow',False),'keychain-access-groups':[team+'.'+bundle]}
(out/'entitlements.plist').write_bytes(plistlib.dumps(ent))
subprocess.run(['codesign','--force','--sign',cert,str(frameworks/'Flutter.framework')],check=True,capture_output=True)
subprocess.run(['codesign','--force','--sign',cert,'--entitlements',str(out/'entitlements.plist'),str(app)],check=True,capture_output=True)
print('Isolated probe built and signed with existing eligible wildcard profile')

# Only the synthetic package is installed/launched. Never uninstall or clear data.
def ordinary(file):
 device_run('info','apps','--filter',"bundleIdentifier == 'com.chaken.phoneagent.test'",'--json-output',str(file))
 return [a for a in json.loads(file.read_text())['result']['apps'] if a.get('bundleIdentifier')=='com.chaken.phoneagent.test']
before=ordinary(out/'ordinary-before.json')
source=ROOT/'ios/Runner/DomesticRecordingChannel.swift'
source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
device_run('install','app',str(app))
def read_report(destination):
 device_run('copy','from','--domain-type','appDataContainer','--domain-identifier',bundle,'--source','Documents/encoding-probe-report.json','--destination',str(destination))
 return json.loads(destination.read_text())
try: old=read_report(out/'previous-report.json').get('runId')
except subprocess.CalledProcessError: old=None
device_run('process','launch','--terminate-existing',bundle)
report=None
for attempt in range(20):
 try:
  value=read_report(out/'report.json')
  if value.get('runId') and value['runId']!=old: report=value;break
 except subprocess.CalledProcessError: pass
 time.sleep(1)
assert report is not None,'Fresh isolated report not available; no blind replay'
assert report.get('success') is True,report
assert report.get('invalidPathsRejected')==4,report
assert ordinary(out/'ordinary-after.json')==before,'Ordinary app install metadata changed'
assert hashlib.sha256(source.read_bytes()).hexdigest()==source_hash,'Native source changed during test'
evidence={'report':report,'nativeSha256':source_hash,'ordinaryAppMetadataUnchanged':True,'noMicrophoneOrAccountAccess':True}
(out/'evidence.json').write_text(json.dumps(evidence,indent=2)+'\n')
print(json.dumps(evidence))
