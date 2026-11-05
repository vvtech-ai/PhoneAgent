Pod::Spec.new do |s|
  s.name = 'PhoneAgentTrustedCaller'
  s.version = '1.0.0'
  s.summary = 'Environment-scoped KXSDK dependencies for PhoneAgent.'
  s.homepage = 'https://gitlab.vvtech.tech/worldcall/phoneagentflutter'
  s.license = { :type => 'Proprietary' }
  s.author = { 'VVTech' => 'https://gitlab.vvtech.tech/worldcall/phoneagentflutter' }
  s.source = { :git => 'https://gitlab.vvtech.tech/worldcall/phoneagentflutter' }
  s.platform = :ios, '16.1'
  s.static_framework = true
  s.source_files = 'Classes/**/*.{h,m}', 'Generated/*.{h,m}'
  s.public_header_files = 'Classes/TrustedCallerSDKAvailability.h', 'Classes/TrustedCallerPlugin.h'
  s.private_header_files = 'Classes/TrustedCallerConfiguration.h',
    'Classes/TrustedCallerAuthorizationEvidence.h', 'Classes/TrustedCallerSdkClient.h',
    'Classes/TrustedCallerSurfaceOwner.h', 'Classes/TrustedCallerSurfaceRequest.h',
    'Classes/TrustedIdentityOverlaySurface.h', 'Classes/TrustedCallerSettingsSurface.h', 'Classes/TrustedCallerNativeIntroduction.h', 'Classes/TrustedCallerPushBindingState.h', 'Classes/TrustedCallerPushBindingDriver.h',
    'Classes/TrustedCallerPushRegistration.h', 'Classes/TrustedCallerPhoneNumber.h', 'Classes/TrustedCallerIncomingPayload.h',
    'Classes/TrustedCallerIdentityEvidence.h', 'Classes/TrustedCallerIncomingDriver.h', 'Classes/TrustedCallerIncomingSession.h', 'Classes/TrustedCallerIncomingDiagnostics.h', 'Classes/TrustedCallerAvatarLoader.h',
    'Classes/TrustedCallerNotificationRouting.h', 'Classes/TrustedCallerNotificationRelay.h',
    'Classes/TrustedCallerCallAssociation.h', 'Classes/TrustedCallerSystemCallObserver.h',
    'Classes/TrustedCallerIdentityLink.h', 'Generated/*.h'
  s.preserve_paths = 'Vendor/**/*', 'SDK_MANIFEST.json'
  s.resources = 'Resources/*'
  s.frameworks = 'Foundation', 'UIKit', 'Security', 'CoreTelephony',
    'SystemConfiguration', 'Network', 'UserNotifications', 'Contacts', 'ContactsUI', 'CallKit'
  s.libraries = 'c++', 'z', 'sqlite3'
  s.dependency 'Flutter'
  s.dependency 'AFNetworking', '4.0.1'
  s.dependency 'SSZipArchive', '2.4.3'
  s.dependency 'OpenSSL-Universal', '1.1.2301'
  s.dependency 'SnapKit', '5.7.1'
  s.dependency 'QMUIKit', '4.6.0'
  s.dependency 'SDWebImage', '5.21.0'
  s.dependency 'Masonry', '1.1.0'
  environment_settings = {
    'PHONEAGENT_TRUSTED_SDK_ENV_dev' => 'test',
    'PHONEAGENT_TRUSTED_SDK_ENV_test' => 'test',
    'PHONEAGENT_TRUSTED_SDK_ENV_prod' => 'pro',
    'PHONEAGENT_TRUSTED_SDK_TEST_dev' => '1',
    'PHONEAGENT_TRUSTED_SDK_TEST_test' => '1',
    'PHONEAGENT_TRUSTED_SDK_TEST_prod' => '0'
  }
  s.script_phase = {
    :name => 'Prepare platform trusted caller credentials',
    :execution_position => :before_compile,
    :show_env_vars_in_log => false,
    :script => 'set -e
set +x
/usr/bin/env python3 -B "${PODS_TARGET_SRCROOT}/../../tool/prepare_trusted_caller_credentials.py" --ios-build
'
  }
  s.pod_target_xcconfig = environment_settings.merge({
    'DEFINES_MODULE' => 'YES',
    'FRAMEWORK_SEARCH_PATHS[sdk=iphoneos*]' => '$(inherited) "$(PODS_TARGET_SRCROOT)/Vendor/$(PHONEAGENT_TRUSTED_SDK_ENV)" "$(PODS_TARGET_SRCROOT)/Vendor/Common"'
  })
  s.user_target_xcconfig = environment_settings.merge({
    'FRAMEWORK_SEARCH_PATHS[sdk=iphoneos*]' => '$(inherited) "$(PODS_ROOT)/../TrustedCallerSDK/Vendor/$(PHONEAGENT_TRUSTED_SDK_ENV)" "$(PODS_ROOT)/../TrustedCallerSDK/Vendor/Common"',
    'OTHER_LDFLAGS[sdk=iphoneos*]' => '$(inherited) -ObjC -framework KXSDK -framework ASN1'
  })
end
