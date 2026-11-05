# Generates an isolated test host in a caller-owned temporary directory.
# Requires the xcodeproj gem already bundled with CocoaPods; installs nothing.
# Usage: ruby tool/prepare_ios_commerce_native_tests.rb TEMP_DIR FLUTTER_SIM_FRAMEWORK
require 'xcodeproj'
require 'fileutils'

output, framework = ARGV
abort 'Provide temporary output directory and Flutter simulator framework' unless output && framework
root = File.expand_path('..', __dir__)
output = File.expand_path(output)
framework = File.expand_path(framework)
abort 'Output must be outside the repository' if output.start_with?(root + '/') || output == root
abort 'Flutter framework not found' unless File.directory?(framework)
FileUtils.mkdir_p(output)
File.write(File.join(output, 'TestAppDelegate.swift'), <<~SWIFT)
  import UIKit
  @main final class TestAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication,
      didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
      window = UIWindow(frame: UIScreen.main.bounds)
      window?.rootViewController = UIViewController()
      window?.makeKeyAndVisible()
      return true
    }
  }
SWIFT
project = Xcodeproj::Project.new(File.join(output, 'CommerceTests.xcodeproj'))
app = project.new_target(:application, 'Runner', :ios, '16.1')
tests = project.new_target(:unit_test_bundle, 'RunnerTests', :ios, '16.1')
tests.add_dependency(app)
app.add_file_references([
  project.main_group.new_file(File.join(output, 'TestAppDelegate.swift')),
  project.main_group.new_file(File.join(root, 'ios/Runner/CommercePaymentChannel.swift')),
  project.main_group.new_file(File.join(root, 'ios/Runner/StoreKitPriceValidation.swift'))
])
tests.add_file_references([
  project.main_group.new_file(File.join(root, 'ios/RunnerTests/RunnerTests.swift'))
])
flutter = project.frameworks_group.new_file(framework)
app.frameworks_build_phase.add_file_reference(flutter)
tests.frameworks_build_phase.add_file_reference(flutter)
embed = app.new_copy_files_build_phase('Embed Flutter test runtime')
embed.dst_subfolder_spec = '10'
embed.add_file_reference(flutter).settings = { 'ATTRIBUTES' => ['CodeSignOnCopy', 'RemoveHeadersOnCopy'] }
[app, tests].each do |target|
  target.build_configurations.each do |config|
    config.build_settings.merge!({
      'SWIFT_VERSION' => '5.0',
      'SDKROOT' => 'iphonesimulator',
      'SUPPORTED_PLATFORMS' => 'iphonesimulator',
      'ARCHS' => 'arm64',
      'EXCLUDED_ARCHS' => '',
      'GENERATE_INFOPLIST_FILE' => 'YES',
      'PRODUCT_BUNDLE_IDENTIFIER' => "local.phoneagent.commerce.#{target.name}",
      'CODE_SIGNING_ALLOWED' => 'YES',
      'CODE_SIGN_IDENTITY' => '-',
      'CODE_SIGNING_REQUIRED' => 'NO',
      'ENABLE_TESTABILITY' => 'YES',
      'FRAMEWORK_SEARCH_PATHS' => ['$(inherited)', File.dirname(framework)],
      'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']
    })
  end
end
tests.build_configurations.each do |config|
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/Runner.app/Runner'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(tests)
scheme.set_launch_target(app)
scheme.test_action.build_configuration = 'Debug'
# Activate local StoreKit for the host as well as the programmatic SKTestSession.
source = File.read(File.join(root, 'ios/RunnerTests/RunnerTests.swift'))
configuration = source.match(/localConfiguration = #"""\n(.*?)\n  """#/m)[1]
File.write(File.join(output, 'LocalCommerce.storekit'), configuration)
scheme.launch_action.xml_element.add_element('StoreKitConfigurationFileReference',
  { 'identifier' => '../../LocalCommerce.storekit' })
scheme.save_as(project.path, 'CommerceTests', true)
puts project.path
