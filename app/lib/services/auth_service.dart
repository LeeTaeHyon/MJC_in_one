import "package:firebase_auth/firebase_auth.dart";
import "package:shared_preferences/shared_preferences.dart";

const String kMjcEmailDomain = "@mjc.ac.kr";
const String kPendingMagicEmailPrefKey = "pending_magic_email";

class MjcDomainException implements Exception {
  const MjcDomainException();

  @override
  String toString() => "@mjc.ac.kr 이메일만 사용할 수 있습니다.";
}

class MissingPendingEmailException implements Exception {
  const MissingPendingEmailException();

  @override
  String toString() => "로그인 링크를 요청한 이메일 정보를 찾을 수 없습니다.";
}

class AuthService {
  AuthService._({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  bool isMjcEmail(String email) {
    return email.trim().toLowerCase().endsWith(kMjcEmailDomain);
  }

  Future<void> sendMagicLink(String email) async {
    final String normalizedEmail = email.trim().toLowerCase();
    if (!isMjcEmail(normalizedEmail)) {
      throw const MjcDomainException();
    }

    final ActionCodeSettings settings = ActionCodeSettings(
      url: "https://mjcinone.web.app/login",
      handleCodeInApp: true,
      androidPackageName: "com.myeongji.mio.mioNotice",
      androidInstallApp: true,
      androidMinimumVersion: "1",
    );

    await _auth.sendSignInLinkToEmail(
      email: normalizedEmail,
      actionCodeSettings: settings,
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPendingMagicEmailPrefKey, normalizedEmail);
  }

  bool isSignInLink(String link) {
    return _auth.isSignInWithEmailLink(link);
  }

  Future<UserCredential> completeSignIn(String link) async {
    if (!isSignInLink(link)) {
      throw FirebaseAuthException(
        code: "invalid-magic-link",
        message: "유효하지 않은 로그인 링크입니다.",
      );
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? email = prefs.getString(kPendingMagicEmailPrefKey);
    if (email == null || email.trim().isEmpty) {
      throw const MissingPendingEmailException();
    }

    final UserCredential credential = await _auth.signInWithEmailLink(
      email: email,
      emailLink: link,
    );

    final String signedInEmail = credential.user?.email ?? email;
    if (!isMjcEmail(signedInEmail)) {
      await _auth.signOut();
      throw const MjcDomainException();
    }

    await prefs.remove(kPendingMagicEmailPrefKey);
    return credential;
  }

  Future<void> signOut() => _auth.signOut();
}
