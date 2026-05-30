import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:mjc_in_one/screens/admin/admin_auth_service.dart";

/// 관리자 로그인 화면 (Email / Password).
///
/// 성공 시 [onSignedIn] 콜백을 호출. 부모(보통 AdminShell)가 권한 재확인 후 다음 화면으로 전환.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, this.onSignedIn});

  final VoidCallback? onSignedIn;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final String email = _emailCtrl.text.trim();
    final String pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = "이메일과 비밀번호를 입력해 주세요.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AdminAuthService.instance.signIn(email: email, password: pass);
      if (!mounted) return;
      widget.onSignedIn?.call();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _humanize(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "로그인 중 오류가 발생했습니다.";
      });
    }
  }

  String _humanize(FirebaseAuthException e) {
    switch (e.code) {
      case "invalid-email":
        return "올바른 이메일 형식이 아닙니다.";
      case "user-disabled":
        return "이 계정은 비활성화되어 있습니다.";
      case "user-not-found":
      case "wrong-password":
      case "invalid-credential":
        return "이메일 또는 비밀번호가 올바르지 않습니다.";
      case "too-many-requests":
        return "잠시 후 다시 시도해 주세요.";
      case "network-request-failed":
        return "네트워크 오류가 발생했습니다. 연결 상태를 확인해 주세요.";
      default:
        return "로그인에 실패했습니다 (${e.code}).";
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "관리자 로그인",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Icon(Icons.shield_outlined, size: 48, color: scheme.primary),
                const SizedBox(height: 12),
                Text(
                  "MJC ONE 관리자",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  "사용자 신고와 개발자 문의를 관리하는 콘솔입니다.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "이메일",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: "비밀번호",
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(color: scheme.error, fontSize: 13),
                    ),
                  ),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          "로그인",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
