typedef DialPermissionFlags = ({
  bool locationShown,
  bool locationRequested,
  bool callLogRequested,
});

abstract interface class DialPermissionStore {
  Future<DialPermissionFlags> read();
  Future<void> write(DialPermissionFlags flags);
}
