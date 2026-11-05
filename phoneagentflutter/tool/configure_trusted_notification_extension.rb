# Mechanical, idempotent standalone NSE wiring; never inherits Flutter/Pods.
require 'xcodeproj'
root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'ios/Runner.xcodeproj'))
runner = project.targets.find { |target| target.name == 'Runner' }
raise 'Runner missing' unless runner
name = 'TrustedCallerNotificationService'
extension = project.targets.find { |target| target.name == name }
extension ||= project.new_target(:app_extension, name, :ios, '16.1')
group = project.main_group.groups.find { |item| item.name == name }
group ||= project.main_group.new_group(name, name)
def reference(group, path)
  group.files.find { |item| item.path == path } || group.new_file(path)
end
%w[NotificationService.swift TrustedNotificationPolicy.swift TrustedNotificationCompletion.swift].each do |path|
  extension.source_build_phase.add_file_reference(reference(group, path), true)
end
reference(group, 'Info.plist')
config_file = reference(group, 'Extension.xcconfig')
extension.build_configurations.each do |config|
  app = runner.build_configurations.find { |item| item.name == config.name }
  raise 'Unknown configuration' unless app
  bundle = config.name == 'Release' ? 'com.chaken.phoneagent' : 'com.chaken.phoneagent.test'
  raise 'Unexpected App identity or missing Team' unless app.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] == bundle && app.build_settings['DEVELOPMENT_TEAM']
  config.base_configuration_reference = config_file
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => "#{bundle}.KXPushServiceExtension",
    'DEVELOPMENT_TEAM' => app.build_settings['DEVELOPMENT_TEAM'],
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'INFOPLIST_FILE' => "#{name}/Info.plist",
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
end
runner.add_dependency(extension) unless runner.dependencies.any? { |item| item.target == extension }
phase = runner.copy_files_build_phases.find { |item| item.name == 'Embed App Extensions' }
phase ||= runner.new_copy_files_build_phase('Embed App Extensions')
phase.dst_subfolder_spec = '13'
phase.add_file_reference(extension.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
thin = runner.build_phases.find { |item| item.display_name == 'Thin Binary' }
raise 'Flutter Thin Binary phase missing' unless thin
runner.build_phases.delete(phase)
runner.build_phases.insert(runner.build_phases.index(thin), phase)
[extension].each do |target|
  # Existing projects may refer to the same source through different groups.
  target.source_build_phase.files.group_by { |file| file.file_ref.real_path.to_s }.each_value do |files|
    files.drop(1).each(&:remove_from_project)
  end
end
project.save
puts 'Trusted notification extension wired for Debug/Profile/Release'
