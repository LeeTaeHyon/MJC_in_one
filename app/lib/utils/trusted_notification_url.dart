const Set<String> _trustedNotificationHosts = <String>{
  "mjcinone.web.app",
  "firebasestorage.googleapis.com",
  "storage.googleapis.com",
};

const Set<String> _notificationOpenUrlKeys = <String>{
  "url",
  "link",
};

const Set<String> _notificationImageUrlKeys = <String>{
  "image",
  "imageUrl",
  "thumbnail",
  "thumb",
  "img",
  "picture",
};

Uri? trustedNotificationLinkUri(String raw) {
  return _trustedNotificationUri(raw, allowStorageHosts: false);
}

String? trustedNotificationImageUrl(String raw) {
  final Uri? uri = _trustedNotificationUri(raw, allowStorageHosts: true);
  return uri?.toString();
}

Map<String, String> sanitizeNotificationDataUrls(Map<String, dynamic> data) {
  final Map<String, String> next = data.map(
    (String key, dynamic value) => MapEntry<String, String>(
      key,
      value?.toString() ?? "",
    ),
  );
  for (final String key in <String>{
    ..._notificationOpenUrlKeys,
    ..._notificationImageUrlKeys,
  }) {
    final String? raw = next[key]?.trim();
    if (raw == null || raw.isEmpty) {
      next.remove(key);
      continue;
    }

    final bool trustedLink = trustedNotificationLinkUri(raw) != null;
    final bool trustedImage = trustedNotificationImageUrl(raw) != null;
    if (!trustedLink && !trustedImage) {
      next.remove(key);
    }
  }
  return next;
}

Uri? _trustedNotificationUri(
  String raw, {
  required bool allowStorageHosts,
}) {
  final String normalized = _normalizeUrl(raw);
  if (normalized.isEmpty) return null;

  final Uri? uri = Uri.tryParse(normalized);
  if (uri == null || uri.scheme != "https" || uri.host.isEmpty) {
    return null;
  }
  if (uri.userInfo.isNotEmpty) return null;

  final String host = uri.host.toLowerCase();
  if (_isMjsHost(host)) return uri;
  if (host == "mjcinone.web.app") return uri;
  if (allowStorageHosts && _trustedNotificationHosts.contains(host)) {
    return uri;
  }
  return null;
}

String _normalizeUrl(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.startsWith("//")) return "https:$trimmed";
  return trimmed;
}

bool _isMjsHost(String host) {
  return host == "mjc.ac.kr" || host.endsWith(".mjc.ac.kr");
}
