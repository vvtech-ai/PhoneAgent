# iOS-only project reference normalization. Never removes files on disk.
module TrustedExtensionReferences
  # ObjectList#delete uses structural equality; identical references can have
  # different UUIDs. delete_at also updates xcodeproj reference bookkeeping.
  def self.detach(list, object)
    index = list.index { |item| item.uuid == object.uuid }
    list.delete_at(index) if index
  end

  def self.group(project, root, name)
    expected = File.expand_path("ios/#{name}", root)
    groups = project.main_group.groups.select { |item| item.real_path.cleanpath.to_s == expected }
    kept = groups.first || project.main_group.new_group(name, name)
    groups.drop(1).each do |duplicate|
      duplicate.children.to_a.dup.each do |child|
        detach(duplicate.children, child)
        kept.children << child
      end
      detach(project.main_group.children, duplicate)
      duplicate.remove_from_project
    end
    kept.files.group_by { |file| file.real_path.cleanpath.to_s }.each_value do |files|
      canonical = files.first
      files.drop(1).each do |duplicate|
        duplicate.referrers.dup.each do |owner|
          case owner
          when Xcodeproj::Project::Object::PBXBuildFile
            owner.file_ref = canonical
          when Xcodeproj::Project::Object::XCBuildConfiguration
            owner.base_configuration_reference = canonical
          when Xcodeproj::Project::Object::PBXGroup
            detach(owner.children, duplicate)
          else
            raise "Unsupported extension reference owner: #{owner.isa}"
          end
        end
        duplicate.remove_from_project
      end
    end
    kept
  end

  def self.embed_phase(runner, product)
    candidates = runner.copy_files_build_phases.select { |phase| phase.files_references.include?(product) }
    if candidates.empty?
      candidates = runner.copy_files_build_phases.select do |phase|
        ['Embed App Extensions', 'Embed Foundation Extensions'].include?(phase.name)
      end
    end
    raise 'Ambiguous extension Embed phases; review before changing wiring' if candidates.length > 1
    candidates.first || runner.new_copy_files_build_phase('Embed App Extensions')
  end

  def self.deduplicate(phase)
    phase.files.group_by { |file| file.file_ref.real_path.cleanpath.to_s }.each_value do |files|
      files.drop(1).each do |duplicate|
        detach(phase.files, duplicate)
        duplicate.remove_from_project
      end
    end
  end
end
