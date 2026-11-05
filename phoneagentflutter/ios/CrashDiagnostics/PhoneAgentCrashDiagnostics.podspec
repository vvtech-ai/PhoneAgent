Pod::Spec.new do |s|
  s.name = 'PhoneAgentCrashDiagnostics'
  s.version = '1.0.0'
  s.summary = 'Private, account-scoped native crash evidence for existing diagnostics.'
  s.homepage = 'https://gitlab.vvtech.tech/worldcall/phoneagentflutter'
  s.license = { :type => 'Proprietary' }
  s.author = { 'VVTech' => 'https://gitlab.vvtech.tech' }
  s.source = { :git => 'https://gitlab.vvtech.tech/worldcall/phoneagentflutter.git' }
  s.platform = :ios, '16.1'
  s.static_framework = true
  s.source_files = 'Classes/*.{h,m}'
  s.public_header_files = 'Classes/PACrashPlugin.h', 'Classes/PAIdentityTrace.h'
  s.dependency 'Flutter'
  s.dependency 'PLCrashReporter', '= 1.12.0'
  s.frameworks = 'Foundation', 'UIKit', 'AVFoundation'
end
