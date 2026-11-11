import 'package:flutter/material.dart';

/// หน้าสมัครสมาชิก (Register) ดีไซน์เดียวกับหน้า Login
///
/// [onRegister] ใช้ต่อ API ทีหลัง: รับ username, email, password แล้วคืนข้อความ error
/// (ถ้าสมัครไม่สำเร็จ) หรือ null (ถ้าสำเร็จ) ถ้าไม่ส่งมา จะจำลองว่าสมัครสำเร็จเสมอ
class RegisterView extends StatefulWidget {
  final Future<String?> Function(String username, String email, String password)? onRegister;

  const RegisterView({super.key, this.onRegister});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final Color primaryGreen = const Color(0xFF0D7A53);
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    String? err;
    if (widget.onRegister != null) {
      err = await widget.onRegister!(_username.text.trim(), _email.text.trim(), _password.text);
    } else {
      await Future.delayed(const Duration(milliseconds: 600)); // TODO: ต่อ API สมัครสมาชิก
    }

    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created! Please log in.')),
    );
    Navigator.pop(context); // กลับไปหน้า Login
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      );

  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
    );
  }

  Widget _eye(bool hidden, VoidCallback onTap) => IconButton(
        icon: Icon(hidden ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.grey),
        onPressed: onTap,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryGreen.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.store, size: 48, color: primaryGreen),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Create account',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign up to start tracking your items',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _label('Username'),
                  TextFormField(
                    controller: _username,
                    textInputAction: TextInputAction.next,
                    decoration: _dec('username', Icons.person_outline),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Please enter a username';
                      if (t.length < 3) return 'At least 3 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _label('Email'),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: _dec('name@example.com', Icons.email_outlined),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Please enter your email';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _label('Password'),
                  TextFormField(
                    controller: _password,
                    obscureText: _hidePassword,
                    textInputAction: TextInputAction.next,
                    decoration: _dec(
                      '••••••••',
                      Icons.lock_outline,
                      suffix: _eye(_hidePassword, () => setState(() => _hidePassword = !_hidePassword)),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter a password';
                      if (v.length < 6) return 'At least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _label('Confirm password'),
                  TextFormField(
                    controller: _confirm,
                    obscureText: _hideConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: _dec(
                      '••••••••',
                      Icons.lock_outline,
                      suffix: _eye(_hideConfirm, () => setState(() => _hideConfirm = !_hideConfirm)),
                    ),
                    validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Register', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?', style: TextStyle(fontSize: 13)),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Log in',
                          style: TextStyle(color: primaryGreen, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
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