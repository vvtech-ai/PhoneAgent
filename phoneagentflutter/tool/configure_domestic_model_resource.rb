# Configure public source/resource wiring; never reads private configuration.
require 'xcodeproj'
project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |item| item.name == 'Runner' }
group = project.main_group.find_subpath('Runner', false)
name = 'DomesticModelConfigurationChannel.swift'
file = group.files.find { |item| item.path == name } || group.new_file(name)
unless target.source_build_phase.files_references.include?(file)
  target.source_build_phase.add_file_reference(file)
end
phase_name = 'Copy private domestic model configuration'
phase = target.shell_script_build_phases.find { |item| item.name == phase_name } || target.new_shell_script_build_phase(phase_name)
phase.shell_script = <<~SCRIPT
  set -e
  input="${SRCROOT}/DomesticModelConfiguration/Private/domestic-model-configuration.json"
  output="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/domestic-model-configuration.json"
  if [ -f "$input" ]; then
    mkdir -p "$(dirname "$output")"
    /usr/bin/install -m 644 "$input" "$output"
  else
    rm -f "$output"
  fi
SCRIPT
phase.always_out_of_date = '1'
project.save
puts 'Domestic model source and optional resource phase configured; no private input read.'
