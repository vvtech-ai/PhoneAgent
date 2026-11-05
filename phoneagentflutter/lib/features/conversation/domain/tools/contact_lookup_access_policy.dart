/// iOS effective native limited-scope contract; no device or UI dependencies.
abstract final class ContactLookupAccessPolicy {
  static const notice = '通讯录仅允许访问部分联系人，请在系统设置中允许更多联系人';
  static Map<String, Object?> phone(
    Map<String, Object?> result,
    bool limited,
  ) => limited
      ? {
          ...result,
          'accessScope': 'limited',
          if (result['found'] != true) 'reason': 'PERMISSION_LIMITED',
        }
      : result;
  static List<Map<String, Object?>> names(
    List<Map<String, Object?>> results,
    bool limited,
  ) => limited
      ? [
          for (final result in results)
            {
              ...result,
              'accessScope': 'limited',
              if (result['status'] == 'NOT_FOUND')
                'status': 'PERMISSION_LIMITED',
            },
        ]
      : results;
}
