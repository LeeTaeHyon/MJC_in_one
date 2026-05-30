import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:mjc_in_one/services/app_config_service.dart";
import "package:shared_preferences/shared_preferences.dart";

/// 개인정보처리방침 시행일과 맞춥니다. 방침·약관 개정 시 이 값을 올리면 재동의가 필요합니다.
const String kLegalConsentVersion = "2026-05-01";

const String kTermsOfServiceUrlFallback = "https://mjcinone.web.app/terms";
const String kPrivacyPolicyUrlFallback = "https://mjcinone.web.app/privacy";

const String _prefVersionKey = "legal_consent_version_v1";
const String _prefAcceptedAtMsKey = "legal_consent_accepted_at_ms_v1";

class LegalConsentRecord {
  const LegalConsentRecord({
    required this.version,
    required this.acceptedAtMs,
  });

  final String version;
  final int acceptedAtMs;

  Map<String, dynamic> toFirestore() {
    return {
      "version": version,
      "acceptedAt": Timestamp.fromMillisecondsSinceEpoch(acceptedAtMs),
      "termsAccepted": true,
      "privacyAccepted": true,
      "overseasTransferAccepted": true,
    };
  }
}

class LegalConsentService {
  LegalConsentService._();

  static final LegalConsentService instance = LegalConsentService._();

  Future<LegalConsentRecord?> loadLocalRecord() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String version = (prefs.getString(_prefVersionKey) ?? "").trim();
    final int acceptedAtMs = prefs.getInt(_prefAcceptedAtMsKey) ?? 0;
    if (version.isEmpty || acceptedAtMs <= 0) return null;
    return LegalConsentRecord(version: version, acceptedAtMs: acceptedAtMs);
  }

  Future<bool> hasValidLocalConsent() async {
    final LegalConsentRecord? record = await loadLocalRecord();
    return record != null && record.version == kLegalConsentVersion;
  }

  Future<void> recordLocalConsent() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefVersionKey, kLegalConsentVersion);
    await prefs.setInt(
      _prefAcceptedAtMsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> applyCloudRecord(Map<String, dynamic> data) async {
    final String version = (data["version"] ?? "").toString().trim();
    final Object? acceptedAt = data["acceptedAt"];
    int acceptedAtMs = 0;
    if (acceptedAt is Timestamp) {
      acceptedAtMs = acceptedAt.millisecondsSinceEpoch;
    } else if (acceptedAt is int) {
      acceptedAtMs = acceptedAt;
    }
    if (version.isEmpty || acceptedAtMs <= 0) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefVersionKey, version);
    await prefs.setInt(_prefAcceptedAtMsKey, acceptedAtMs);
  }

  Future<void> syncToCloud(User user) async {
    final LegalConsentRecord? record = await loadLocalRecord();
    if (record == null || record.version != kLegalConsentVersion) return;

    try {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set(
        {"legalConsent": record.toFirestore()},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Ignore cloud sync failures
    }
  }

  Future<String> resolveTermsUrl() async {
    final String? url = await AppConfigService.loadLink("termsOfServiceUrl");
    return _normalizeLegalUrl(url, kTermsOfServiceUrlFallback);
  }

  Future<String> resolvePrivacyUrl() async {
    final String? url = await AppConfigService.loadLink("privacyPolicyUrl");
    return _normalizeLegalUrl(url, kPrivacyPolicyUrlFallback);
  }
}

String _normalizeLegalUrl(String? raw, String fallback) {
  final String trimmed = (raw ?? "").trim();
  if (trimmed.isEmpty) return fallback;

  final Uri? uri = Uri.tryParse(trimmed);
  if (uri == null) return fallback;

  if (uri.hasScheme && (uri.scheme == "http" || uri.scheme == "https")) {
    return trimmed;
  }

  if (trimmed.startsWith("/")) {
    return "https://mjcinone.web.app$trimmed";
  }

  return fallback;
}
