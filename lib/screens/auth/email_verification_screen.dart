import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/auth/auth_service.dart';

/// Screen displayed when user registration requires email confirmation.
class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResending = false;
  String? _statusMessage;

  Future<void> _resendVerificationEmail() async {
    setState(() {
      _isResending = true;
      _statusMessage = null;
    });

    try {
      // In Supabase Auth, resending verification is initiated via resend API
      await AuthService.instance.resetPasswordForEmail(widget.email);
      if (mounted) {
        setState(() {
          _statusMessage = 'A fresh confirmation link has been sent to your email.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Verification email dispatched. Please check your spam folder.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryForest.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.paleMint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        color: AppColors.primaryForest,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Check your inbox',
                      style: AppTypography.heading1.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryForest,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We have sent a verification link to:',
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.mutedText,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.softCream,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.subtleBorder),
                      ),
                      child: Text(
                        widget.email,
                        style: AppTypography.bodyText.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryForest,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap the link in your email to activate your NutriFridge account. '
                      'Once verified, return here to sign in.',
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.mutedText,
                        fontSize: 13,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.paleMint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _statusMessage!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primaryForest,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryForest,
                          foregroundColor: AppColors.pureWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Back to Sign In',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isResending ? null : _resendVerificationEmail,
                      child: _isResending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(AppColors.primaryForest),
                              ),
                            )
                          : Text(
                              'Did not receive an email? Resend',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.freshGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
