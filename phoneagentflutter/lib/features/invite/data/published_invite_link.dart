import '../domain/invite_link_policy.dart';

/// Validates a signed API's published link separately from incoming deep links.
bool matchesPublishedInviteLink(String url, String code) {
  if (url.length > 2048 || !InviteLinkPolicy.validCode(code)) return false;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
  return InviteLinkPolicy(
        host: uri.host,
        path: uri.path,
        scheme: '',
      ).parse(url) ==
      code;
}
