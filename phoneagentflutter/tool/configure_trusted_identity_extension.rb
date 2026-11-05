# Mechanical, idempotent Xcode target wiring; run with CocoaPods' GEM_HOME.
require 'xcodeproj'
require_relative 'trusted_extension_references'
root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'ios/Runner.xcodeproj'))
runner = project.targets.find { |target| target.name == 'Runner' }
raise 'Runner missing' unless runner
name = 'TrustedIdentityLiveActivity'
extension = project.targets.find { |target| target.name == name }
extension ||= project.new_target(:app_extension, name, :ios, '16.1')
group = TrustedExtensionReferences.group(project, root, name)
def reference(group, path)
  group.files.find { |item| item.path == path } || group.new_file(path)
end
attributes = reference(group, 'TrustedIdentityActivityAttributes.swift')
view = reference(group, 'TrustedIdentityLiveActivity.swift')
assets = reference(group, 'Assets.xcassets')
reference(group, 'Info.plist')
config_file = reference(group, 'Extension.xcconfig')
[attributes, view].each { |file| extension.source_build_phase.add_file_reference(file, true) }
extension.resources_build_phase.add_file_reference(assets, true)
runner.source_build_phase.add_file_reference(attributes, true)
runner_group = project.main_group.groups.find { |item| item.name == 'Runner' || item.path == 'Runner' }
raise 'Runner group missing' unless runner_group
%w[TrustedIdentityActivityProjection.swift TrustedIdentityActivityManager.swift TrustedIdentityActivityAdmission.swift].each do |path|
  runner.source_build_phase.add_file_reference(reference(runner_group, path), true)
end
extension.build_configurations.each do |config|
  app_config = runner.build_configurations.find { |item| item.name == config.name }
  raise 'Unsupported configuration' unless app_config
  bundle = app_config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']
  expected = config.name == 'Release' ? 'com.chaken.phoneagent' : 'com.chaken.phoneagent.test'
  raise 'Unexpected app identity' unless bundle == expected
  config.base_configuration_reference = config_file
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => "#{bundle}.KXLiveActivityExtension",
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'INFOPLIST_FILE' => 'TrustedIdentityLiveActivity/Info.plist',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'IPHONEOS_DEPLOYMENT_TARGET' => '16.1',
    'SWIFT_VERSION' => '5.0',
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'SKIP_INSTALL' => 'YES',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'CODE_SIGN_STYLE' => 'Automatic',
    'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
    'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  )
  team = app_config.build_settings['DEVELOPMENT_TEAM']
  config.build_settings['DEVELOPMENT_TEAM'] = team if team
end
runner.add_dependency(extension) unless runner.dependencies.any? { |dependency| dependency.target == extension }
phase = TrustedExtensionReferences.embed_phase(runner, extension.product_reference)
phase.dst_subfolder_spec = '13'
phase.add_file_reference(extension.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
thin = runner.build_phases.find { |item| item.display_name == 'Thin Binary' }
raise 'Flutter Thin Binary phase missing' unless thin
runner.build_phases.delete(phase)
runner.build_phases.insert(runner.build_phases.index(thin), phase)
[runner, extension].each do |target|
  TrustedExtensionReferences.deduplicate(target.source_build_phase)
end
TrustedExtensionReferences.deduplicate(extension.resources_build_phase)
TrustedExtensionReferences.deduplicate(phase)

project.save
puts 'Trusted identity extension target wired for Debug/Profile/Release'
