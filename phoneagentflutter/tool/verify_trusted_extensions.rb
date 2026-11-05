require 'xcodeproj'
require 'digest'
root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'ios/Runner.xcodeproj'))
runner = project.targets.find { |target| target.name == 'Runner' }
raise 'Runner missing' unless runner
extensions = {
  'TrustedIdentityLiveActivity' => 'KXLiveActivityExtension',
  'TrustedCallerNotificationService' => 'KXPushServiceExtension'
}
phase = runner.copy_files_build_phases.find { |item| item.name == 'Embed App Extensions' }
raise 'Missing Embed phase' unless phase
extensions.each do |name, suffix|
  target = project.targets.find { |item| item.name == name }
  raise 'Missing extension' unless target
  raise 'Missing target dependency' unless runner.dependencies.any? { |item| item.target == target }
  raise 'Duplicate or missing embedded product' unless phase.files.count { |item| item.file_ref == target.product_reference } == 1
  target.build_configurations.each do |config|
    app = runner.build_configurations.find { |item| item.name == config.name }
    bundle = config.name == 'Release' ? 'com.chaken.phoneagent' : 'com.chaken.phoneagent.test'
    settings = config.build_settings
    raise 'App identity mismatch' unless app.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] == bundle
    raise 'Extension identity mismatch' unless settings['PRODUCT_BUNDLE_IDENTIFIER'] == "#{bundle}.#{suffix}"
    raise 'Extension Team mismatch' unless settings['DEVELOPMENT_TEAM'] == app.build_settings['DEVELOPMENT_TEAM']
    raise 'Extension API restriction missing' unless settings['APPLICATION_EXTENSION_API_ONLY'] == 'YES'
    raise 'Extension versions not shared' unless settings['CURRENT_PROJECT_VERSION'] == '$(FLUTTER_BUILD_NUMBER)' && settings['MARKETING_VERSION'] == '$(FLUTTER_BUILD_NAME)'
    raise 'Generated versions not included' unless config.base_configuration_reference && File.read(config.base_configuration_reference.real_path).include?('../Flutter/Generated.xcconfig')
  end
  sources = target.source_build_phase.files_references.map(&:real_path)
  raise 'Duplicate sources' unless sources.uniq == sources
  if name == 'TrustedCallerNotificationService'
    raise 'Unexpected NSE sources' unless sources.map { |path| path.basename.to_s }.sort == %w[NotificationService.swift TrustedNotificationCompletion.swift TrustedNotificationPolicy.swift].sort
    raise 'NSE must not link Flutter/SDK' unless target.frameworks_build_phase.files_references.all? { |file| file.path.end_with?('/Foundation.framework') && file.source_tree == 'DEVELOPER_DIR' }
  end
end
puts 'Both extensions: three configurations, exact Bundle IDs, App Team/version, dependencies and Embed verified.'
