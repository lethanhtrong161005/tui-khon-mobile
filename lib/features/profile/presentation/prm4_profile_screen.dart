import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/login_screen.dart';
import '../data/profile_repository.dart';

class Prm4ProfileScreen extends StatefulWidget {
  const Prm4ProfileScreen({super.key});

  @override
  State<Prm4ProfileScreen> createState() => _Prm4ProfileScreenState();
}

class _Prm4ProfileScreenState extends State<Prm4ProfileScreen> {
  final ProfileRepository _repository = ProfileRepository();
  late Future<UserProfile> _profileFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _repository.getProfile();
  }

  void _reload() {
    setState(() {
      _profileFuture = _repository.getProfile();
    });
  }

  Future<void> _edit(UserProfile profile) async {
    final name = TextEditingController(text: profile.displayName);
    final phone = TextEditingController(text: profile.phoneNumber ?? '');
    final avatar = TextEditingController(text: profile.avatarUrl ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    try {
      final changed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Chỉnh sửa hồ sơ'),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'Tên hiển thị',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập tên';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: profile.email,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            helperText: 'BE chưa hỗ trợ đổi email',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: avatar,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'URL ảnh đại diện',
                            helperText: 'Cần API upload để chọn ảnh từ máy',
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isNotEmpty &&
                                !text.startsWith('https://') &&
                                !text.startsWith('http://')) {
                              return 'Nhập URL http hoặc https';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(dialogContext, false),
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            setDialogState(() => saving = true);
                            try {
                              await _repository.updateProfile(
                                displayName: name.text,
                                phoneNumber: phone.text,
                                avatarUrl: avatar.text,
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, true);
                              }
                            } catch (error) {
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text('Lưu thất bại: $error'),
                                  ),
                                );
                                setDialogState(() => saving = false);
                              }
                            }
                          },
                    child: Text(saving ? 'Đang lưu...' : 'Lưu'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (changed == true) _reload();
    } finally {
      name.dispose();
      phone.dispose();
      avatar.dispose();
    }
  }

  Future<void> _changePassword() async {
    final oldPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmation = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Đổi mật khẩu'),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: oldPassword,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mật khẩu hiện tại',
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Vui lòng nhập mật khẩu'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: newPassword,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mật khẩu mới',
                          ),
                          validator: (value) =>
                              value == null || value.length < 6
                                  ? 'Ít nhất 6 ký tự'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmation,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Xác nhận mật khẩu mới',
                          ),
                          validator: (value) => value != newPassword.text
                              ? 'Mật khẩu không khớp'
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        saving ? null : () => Navigator.pop(dialogContext),
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            setDialogState(() => saving = true);
                            try {
                              await _repository.changePassword(
                                oldPassword: oldPassword.text,
                                newPassword: newPassword.text,
                                confirmPassword: confirmation.text,
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đổi mật khẩu thành công'),
                                  ),
                                );
                              }
                            } catch (error) {
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Đổi mật khẩu thất bại: $error',
                                    ),
                                  ),
                                );
                                setDialogState(() => saving = false);
                              }
                            }
                          },
                    child: Text(saving ? 'Đang lưu...' : 'Xác nhận'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      oldPassword.dispose();
      newPassword.dispose();
      confirmation.dispose();
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text(
          'Bạn sẽ cần đăng nhập lại để xem dữ liệu tài khoản.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _repository.logout();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Đăng xuất thất bại: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: FutureBuilder<UserProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Chưa tải được hồ sơ:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _reload,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final profile = snapshot.data!;
          final avatar = profile.avatarUrl;
          final hasAvatar = avatar != null && avatar.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage:
                            hasAvatar ? NetworkImage(avatar) : null,
                        child: hasAvatar
                            ? null
                            : const Icon(Icons.person, size: 34),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.displayName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(profile.email),
                            Text(profile.phoneNumber ?? 'Chưa có SĐT'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Chỉnh sửa hồ sơ'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _edit(profile),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Đổi mật khẩu'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changePassword,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: appThemeMode,
                  builder: (context, mode, _) {
                    return SwitchListTile(
                      secondary: const Icon(Icons.dark_mode_outlined),
                      title: const Text('Giao diện tối'),
                      value: mode == ThemeMode.dark,
                      onChanged: setDarkMode,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(_busy ? 'Đang đăng xuất...' : 'Đăng xuất'),
                  onTap: _busy ? null : _logout,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
