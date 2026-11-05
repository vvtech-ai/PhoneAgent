import 'clone_creation.dart';

enum CloneEntitlement { allowed, denied, unknown }

const cloneEntitlementUnavailable = '声音克隆权益读取失败，请重试';

CloneEntitlement cloneEntitlement(CloneCreationModel model) {
  if (model.entitlementReason == 'ENTITLEMENT_UNAVAILABLE' ||
      model.cloneEntitled == null) {
    return CloneEntitlement.unknown;
  }
  return model.cloneEntitled!
      ? CloneEntitlement.allowed
      : CloneEntitlement.denied;
}
