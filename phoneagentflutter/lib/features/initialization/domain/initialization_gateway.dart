import '../../identity/domain/identity_profile.dart';

class InitializationModel {
  const InitializationModel(
    this.id,
    this.name,
    this.description, {
    this.enabled = true,
    this.recommended = false,
  });
  final String id, name, description;
  final bool enabled, recommended;

  /// Fixed shared native onboarding copy; availability still comes from catalog.
  String get capability => switch (id.trim().toUpperCase()) {
    'QWEN_OMNI_PLUS' || 'QWEN_OMNI_FLASH' => '支持系统音色和声音克隆',
    'DOUBAO' => '仅支持系统音色',
    _ => '',
  };
}

class InitializationCatalog {
  const InitializationCatalog(this.selected, this.models);
  final String selected;
  final List<InitializationModel> models;
  bool permits(String id) => models.any((m) => m.id == id && m.enabled);
}

abstract interface class InitializationGateway {
  Future<bool> isSkipped();
  Future<IdentityProfile> loadIdentity();
  Future<InitializationCatalog> loadCallModels();
  Future<void> selectCallModel(String id);
  Future<void> saveIdentity(IdentityDraft draft);
  Future<void> markSkipped();
}
