import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? user;
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final value = await ApiService.getProfile();
      if (mounted) setState(() => user = value);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _open(Widget page) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => page));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final name = user?['fullName']?.toString() ?? '';
    final email = user?['email']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ cá nhân')),
      body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          CircleAvatar(radius: 42, child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(fontSize: 32))),
          const SizedBox(height: 16),
          Center(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          Center(child: Text(email, style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 28),
          Card(child: ListTile(leading: const Icon(Icons.person_outline), title: const Text('Họ và tên'), subtitle: Text(name))),
          Card(child: ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email'), subtitle: Text(email))),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _open(EditProfileScreen(fullName: name, email: email)),
            icon: const Icon(Icons.edit), label: const Text('Cập nhật hồ sơ')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _open(const ChangePasswordScreen()),
            icon: const Icon(Icons.lock_outline), label: const Text('Đổi mật khẩu')),
        ]),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final String fullName, email;
  const EditProfileScreen({super.key, required this.fullName, required this.email});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final keyForm = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.fullName);
  late final email = TextEditingController(text: widget.email);
  bool saving = false;

  @override
  void dispose() { name.dispose(); email.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!keyForm.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await ApiService.updateProfile(name.text.trim(), email.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật hồ sơ thành công')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cập nhật hồ sơ')),
    body: Form(key: keyForm, child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Họ và tên'),
      const SizedBox(height: 8),
      TextFormField(controller: name, validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ tên' : null),
      const SizedBox(height: 18),
      const Text('Email'),
      const SizedBox(height: 8),
      TextFormField(controller: email, keyboardType: TextInputType.emailAddress,
        validator: (v) => v == null || !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim()) ? 'Email không hợp lệ' : null),
      const SizedBox(height: 24),
      FilledButton(onPressed: saving ? null : _save, child: Text(saving ? 'Đang lưu...' : 'Lưu thay đổi')),
    ])),
  );
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final keyForm = GlobalKey<FormState>();
  final current = TextEditingController(), next = TextEditingController(), confirm = TextEditingController();
  bool saving = false, hide = true;

  @override
  void dispose() { current.dispose(); next.dispose(); confirm.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!keyForm.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await ApiService.changePassword(current.text, next.text, confirm.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => saving = false); }
  }

  Widget _field(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(controller: controller, obscureText: hide,
      decoration: InputDecoration(labelText: label, suffixIcon: IconButton(
        onPressed: () => setState(() => hide = !hide),
        icon: Icon(hide ? Icons.visibility : Icons.visibility_off))),
      validator: (v) => v == null || v.length < 8 ? 'Mật khẩu phải có ít nhất 8 ký tự' : null),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đổi mật khẩu')),
    body: Form(key: keyForm, child: ListView(padding: const EdgeInsets.all(20), children: [
      _field('Mật khẩu hiện tại', current),
      _field('Mật khẩu mới', next),
      _field('Nhập lại mật khẩu mới', confirm),
      const SizedBox(height: 8),
      FilledButton(onPressed: saving ? null : _save, child: Text(saving ? 'Đang cập nhật...' : 'Đổi mật khẩu')),
    ])),
  );
}
