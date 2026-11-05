Pod::Spec.new do |s|
  s.name = 'PhoneAgentIdentityCapture'
  s.version = '1.0.0'
  s.summary = 'Session-scoped Flutter boundary for the pinned identity capture SDK.'
  s.homepage = 'https://gitlab.vvtech.tech/worldcall/phoneagentflutter'
  s.license = { :type => 'Proprietary' }
  s.author = { 'VVTech' => 'https://gitlab.vvtech.tech/worldcall/phoneagentflutter' }
  s.source = { :git => 'https://gitlab.vvtech.tech/worldcall/phoneagentflutter.git' }
  s.platform = :ios, '16.1'
  # SDK binaries are static; keep vendor resource bundles at the app root as required.
  s.static_framework = true
  s.source_files = 'Classes/**/*.{h,m}'
  s.public_header_files = 'Classes/IdentityCapturePlugin.h'
  s.dependency 'Flutter'
  s.dependency 'PhoneAgentCrashDiagnostics'
  s.vendored_frameworks = 'Vendor/*.framework'
  s.resources = 'Vendor/**/*.bundle'
  s.frameworks = 'CoreGraphics', 'Accelerate', 'SystemConfiguration', 'AssetsLibrary',
    'CoreTelephony', 'QuartzCore', 'CoreFoundation', 'CoreLocation', 'ImageIO',
    'CoreMedia', 'CoreMotion', 'AVFoundation', 'WebKit', 'AudioToolbox', 'CFNetwork',
    'MobileCoreServices', 'AdSupport', 'ReplayKit', 'CoreNFC', 'CallKit'
  s.libraries = 'c++', 'resolv', 'z'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.user_target_xcconfig = { 'OTHER_LDFLAGS' => '$(inherited) -ObjC' }
end
