enum IdentityStatus { empty, filled, verified }

enum IdentityValidation { nameRequired, invalidPhone }

class WorkIdentity {
  const WorkIdentity({
    this.company = '',
    this.department = '',
    this.position = '',
  });
  final String company, department, position;
  WorkIdentity normalized() => WorkIdentity(
    company: company.trim(),
    department: department.trim(),
    position: position.trim(),
  );
}

class IdentityProfile {
  const IdentityProfile({
    required this.accountId,
    this.name = '',
    this.gender = '',
    this.contactPhone = '',
    this.workIdentities = const [],
    this.description = '',
    this.verificationStatus = '',
    this.certNoMasked = '',
    this.verifiedAt = '',
    this.updatedAt = '',
  });
  final String accountId,
      name,
      gender,
      contactPhone,
      description,
      verificationStatus,
      certNoMasked,
      verifiedAt,
      updatedAt;
  final List<WorkIdentity> workIdentities;
  IdentityStatus get status => name.trim().isEmpty
      ? IdentityStatus.empty
      : verificationStatus.trim().toUpperCase() == 'VERIFIED'
      ? IdentityStatus.verified
      : IdentityStatus.filled;
}

class IdentityDraft {
  const IdentityDraft({
    this.name = '',
    this.gender = '不透露',
    this.contactPhone = '',
    this.workIdentities = const [],
    this.description = '',
  });
  factory IdentityDraft.from(IdentityProfile profile) => IdentityDraft(
    name: profile.name,
    gender: profile.gender.trim().isEmpty ? '不透露' : profile.gender,
    contactPhone: profile.contactPhone.trim(),
    workIdentities: profile.workIdentities,
    description: profile.description,
  );
  final String name, gender, contactPhone, description;
  final List<WorkIdentity> workIdentities;
  IdentityValidation? get validation {
    if (name.trim().isEmpty) return IdentityValidation.nameRequired;
    if (contactPhone.trim().isNotEmpty &&
        !RegExp(r'^1[3-9]\d{9}$').hasMatch(contactPhone.trim())) {
      return IdentityValidation.invalidPhone;
    }
    return null;
  }

  IdentityDraft edit({String? name, String? gender, String? phone}) =>
      IdentityDraft(
        name: name == null
            ? this.name
            : name.substring(0, name.length > 128 ? 128 : name.length),
        gender: gender ?? this.gender,
        contactPhone: phone == null ? contactPhone : _phone(phone),
        workIdentities: workIdentities,
        description: description,
      );
  static String _phone(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.substring(0, digits.length > 11 ? 11 : digits.length);
  }
}

abstract interface class IdentityRepository {
  Future<IdentityProfile> load();
  Future<IdentityProfile> save(IdentityDraft draft, {required bool verified});
  Future<IdentityProfile> delete();
}
