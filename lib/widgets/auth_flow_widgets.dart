import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_glass.dart';
import 'glass_form_widgets.dart';

class AuthFlowScaffold extends StatelessWidget {
  final Widget child;
  final bool scrollable;

  const AuthFlowScaffold({
    super.key,
    required this.child,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassRouteBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: scrollable
            ? SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    MediaQuery.paddingOf(context).top + 40,
                    24,
                    28 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: child,
                ),
              )
            : child,
      ),
    );
  }
}

class AuthHeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const AuthHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.sports_hockey_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppGlassSurface(
          height: 96,
          radius: 26,
          child: Center(
            child: Icon(
              icon,
              size: 42,
              color: AppGlassColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          title,
          style: const TextStyle(
            color: AppGlassColors.ink,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            height: 1.02,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppGlassColors.inkMuted,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class AuthTopBar extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onBack;
  final IconData backIcon;

  const AuthTopBar({
    super.key,
    required this.title,
    required this.icon,
    this.onBack,
    this.backIcon = Icons.arrow_back_ios_new,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, topInset, 20, 12),
      child: Row(
        children: [
          Tooltip(
            message: 'Back',
            child: AppGlassSurface(
              width: 44,
              height: 44,
              padding: EdgeInsets.zero,
              radius: 22,
              onTap: onBack ??
                  () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      Navigator.of(context).maybePop();
                    }
                  },
              child: Center(
                child: Icon(
                  backIcon,
                  size: 18,
                  color: AppGlassColors.ink.withValues(alpha: 0.94),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: AppGlassSurface(
              height: 40,
              padding: const EdgeInsets.fromLTRB(8, 0, 14, 0),
              radius: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      color: AppGlassColors.aqua.withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppGlassColors.aqua.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: AppGlassColors.ink.withValues(alpha: 0.94),
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppGlassColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppGlassColors.border,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: TextStyle(
              color: AppGlassColors.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AppGlassColors.border,
          ),
        ),
      ],
    );
  }
}

class AuthSecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      radius: 22,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppGlassColors.aqua),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppGlassColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthTextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const AuthTextLink({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: AppGlassColors.aqua),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

IconButton glassPasswordToggle({
  required bool obscure,
  required VoidCallback onPressed,
}) {
  return IconButton(
    tooltip: obscure ? 'Show password' : 'Hide password',
    icon: Icon(
      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      color: AppGlassColors.inkMuted,
    ),
    onPressed: onPressed,
  );
}

class AuthDialogSurface extends StatelessWidget {
  final String title;
  final String message;
  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const AuthDialogSurface({
    super.key,
    required this.title,
    required this.message,
    required this.controller,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AppGlassSurface(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        radius: 30,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppGlassColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                color: AppGlassColors.inkSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            GlassTextFormField(
              controller: controller,
              labelText: 'Email',
              leadingIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: AppGlassColors.aqua,
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: onSubmit,
                  style: TextButton.styleFrom(
                    foregroundColor: AppGlassColors.ink,
                  ),
                  child: const Text('Send Reset Link'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
