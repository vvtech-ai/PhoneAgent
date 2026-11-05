/// v65 developer simulation, not OS connectivity or a transport interceptor.
enum DeveloperNetworkMode {
  normal,
  weak,
  offline;

  bool get blocksOnlineEntry => this == offline;
}
