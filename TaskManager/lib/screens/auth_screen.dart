import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const AuthScreen({super.key, required this.onAuthenticated});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool isLogin = true, obscure = true, loading = false;

  @override
  void dispose() { _name.dispose(); _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      if (isLogin) {
        await ApiService.login(_email.text.trim(), _password.text);
      } else {
        await ApiService.register(_name.text.trim(), _email.text.trim(), _password.text);
        // Một số backend chỉ trả user sau đăng ký, không tự cấp token.
        if (await ApiService.getToken() == null) {
          await ApiService.login(_email.text.trim(), _password.text);
        }
      }
      if (!mounted) return;
      widget.onAuthenticated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blue = const Color(0xFF3867F4);
    return Scaffold(
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 76, height: 76, alignment: Alignment.center,
              decoration: BoxDecoration(color: blue, borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: blue.withOpacity(.25), blurRadius: 22, offset: const Offset(0, 10))]),
              child: const Icon(Icons.checklist_rounded, color: Colors.white, size: 42)),
            const SizedBox(height: 28),
            Text(isLogin ? 'Chào mừng trở lại!' : 'Tạo tài khoản mới',
              style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800, color: Color(0xFF17213A))),
            const SizedBox(height: 8),
            Text(isLogin ? 'Đăng nhập để tiếp tục quản lý công việc.' : 'Đăng ký để bắt đầu sắp xếp công việc của bạn.',
              style: const TextStyle(color: Color(0xFF7A849B), fontSize: 15)),
            const SizedBox(height: 30),
            if (!isLogin) ...[
              _label('Họ và tên'),
              TextFormField(controller: _name, textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Nguyễn Văn A', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ tên' : null),
              const SizedBox(height: 17),
            ],
            _label('Email'),
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'name@example.com', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) => v == null || !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim()) ? 'Email không hợp lệ' : null),
            const SizedBox(height: 17),
            _label('Mật khẩu'),
            TextFormField(controller: _password, obscureText: obscure,
              decoration: InputDecoration(hintText: 'Nhập mật khẩu', prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
              validator: (v) => v == null || v.length < 6 ? 'Mật khẩu cần ít nhất 6 ký tự' : null),
            const SizedBox(height: 25),
            SizedBox(height: 54, child: FilledButton(
              onPressed: loading ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: loading ? const SizedBox(width: 23, height: 23, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isLogin ? 'Đăng nhập' : 'Đăng ký', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(isLogin ? 'Chưa có tài khoản? ' : 'Đã có tài khoản? ', style: const TextStyle(color: Color(0xFF7A849B))),
              TextButton(onPressed: loading ? null : () => setState(() => isLogin = !isLogin),
                child: Text(isLogin ? 'Đăng ký ngay' : 'Đăng nhập', style: TextStyle(color: blue, fontWeight: FontWeight.bold))),
            ]),
          ]),
        )),
      ))),
    );
  }

  Widget _label(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF303B54))),
  );
}
