import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../providers/auth_providers.dart';
import 'widgets/auth_widgets.dart';

/// ResetPasswordScreen sets a new password after the recovery code was verified.
/// Leaving without saving signs the temporary session out again.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  Future<void> _save() async {
    final password = _passwordController.text;
    if (password.length < 6) {
      showAuthMessage(context, 'Mật khẩu cần ít nhất 6 ký tự');
      return;
    }
    if (password != _confirmController.text) {
      showAuthMessage(context, 'Mật khẩu nhập lại không khớp');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(password);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      ref.read(passwordRecoveryPendingProvider.notifier).state = false;
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công!')));
    } catch (e) {
      if (mounted) showAuthMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel() async {
    final navigator = Navigator.of(context);
    await ref.read(authRepositoryProvider).signOut();
    ref.read(passwordRecoveryPendingProvider.notifier).state = false;
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isLoading) _cancel();
      },
      child: AuthScaffold(
        onBack: _isLoading ? () {} : _cancel,
        children: [
          const AuthBrandHeader(
            title: 'Đặt mật khẩu mới',
            subtitle: 'Chọn mật khẩu mới cho tài khoản Túi Khôn của bạn',
            icon: Icons.password,
          ),
          const SizedBox(height: 28),
          AuthTextField(
            controller: _passwordController,
            icon: Icons.lock_outline,
            hint: 'Mật khẩu mới (ít nhất 6 ký tự)',
            isPassword: true,
            autofillHints: const [AutofillHints.newPassword],
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _confirmController,
            icon: Icons.lock_reset,
            hint: 'Nhập lại mật khẩu mới',
            isPassword: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(label: 'Lưu mật khẩu', isLoading: _isLoading, onPressed: _save, icon: Icons.check),
        ],
      ),
    );
  }
}
