import 'package:flutter/material.dart';
import 'app_glass.dart';

class GlassFormSectionLabel extends StatelessWidget {
  final String label;

  const GlassFormSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppGlassColors.inkMuted,
        letterSpacing: 0.2,
      ),
    );
  }
}

class GlassTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final IconData? leadingIcon;
  final bool enabled;
  final bool autofocus;
  final bool autocorrect;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  const GlassTextFormField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.leadingIcon,
    this.enabled = true,
    this.autofocus = false,
    this.autocorrect = true,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 22,
      child: Theme(
        data: glassFormTheme(context),
        child: TextFormField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          autocorrect: autocorrect,
          minLines: minLines,
          maxLines: maxLines,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          cursorColor: AppGlassColors.aqua,
          style: const TextStyle(
            color: AppGlassColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            prefixIcon: leadingIcon == null
                ? null
                : Icon(leadingIcon, color: AppGlassColors.inkSecondary),
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: validator,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class GlassDropdownField<T> extends StatelessWidget {
  final T? value;
  final String? hintText;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const GlassDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 22,
      child: Theme(
        data: glassFormTheme(context),
        child: DropdownButtonFormField<T>(
          key: ValueKey<Object?>(value),
          initialValue: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          dropdownColor: const Color(0xFF132238),
          borderRadius: BorderRadius.circular(18),
          iconEnabledColor: AppGlassColors.inkSecondary,
          iconDisabledColor: AppGlassColors.inkMuted,
          style: const TextStyle(
            color: AppGlassColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          hint: hintText == null
              ? null
              : Text(
                  hintText!,
                  style: const TextStyle(
                    color: AppGlassColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          decoration: const InputDecoration(
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.fromLTRB(16, 14, 14, 14),
          ),
        ),
      ),
    );
  }
}

class GlassChoiceOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;

  const GlassChoiceOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.leading,
  });
}

class GlassChoiceWrap<T> extends StatelessWidget {
  final List<GlassChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T>? onChanged;
  final double spacing;
  final double runSpacing;
  final double minItemWidth;
  final double? maxItemWidth;

  const GlassChoiceWrap({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.spacing = 8,
    this.runSpacing = 8,
    this.minItemWidth = 0,
    this.maxItemWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: options.map((option) {
        return GlassChoiceChip(
          label: option.label,
          icon: option.icon,
          leading: option.leading,
          selected: selected == option.value,
          minWidth: minItemWidth,
          maxWidth: maxItemWidth,
          onTap: onChanged == null ? null : () => onChanged!(option.value),
        );
      }).toList(),
    );
  }
}

class GlassScopeSelector<T> extends StatelessWidget {
  final List<GlassChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T>? onChanged;

  const GlassScopeSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(options.length, (index) {
        final option = options[index];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == options.length - 1 ? 0 : 8,
            ),
            child: GlassChoiceChip(
              label: option.label,
              icon: option.icon,
              leading: option.leading,
              selected: selected == option.value,
              onTap: onChanged == null ? null : () => onChanged!(option.value),
            ),
          ),
        );
      }),
    );
  }
}

class GlassChoiceChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;
  final double height;
  final double minWidth;
  final double? maxWidth;

  const GlassChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.leading,
    this.height = 52,
    this.minWidth = 0,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = AppGlassColors.aqua.withValues(alpha: 0.13);
    final selectedBorder = AppGlassColors.aqua.withValues(alpha: 0.34);

    final chip = AppGlassSurface(
      height: height,
      padding: EdgeInsets.zero,
      radius: 18,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? selectedBorder : Colors.transparent,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ] else if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? AppGlassColors.aqua
                      : AppGlassColors.inkSecondary,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        selected ? AppGlassColors.ink : AppGlassColors.inkMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (minWidth == 0 && maxWidth == null) return chip;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        maxWidth: maxWidth ?? double.infinity,
      ),
      child: chip,
    );
  }
}

class GlassIconChoice extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const GlassIconChoice({
    super.key,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      width: 60,
      height: 50,
      padding: EdgeInsets.zero,
      radius: 18,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? AppGlassColors.aqua.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppGlassColors.aqua.withValues(alpha: 0.34)
                : Colors.transparent,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: selected ? AppGlassColors.aqua : AppGlassColors.inkSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class GlassSubmitButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;
  final Key? buttonKey;

  const GlassSubmitButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !isLoading;

    return Opacity(
      opacity: enabled || isLoading ? 1 : 0.55,
      child: AppGlassSurface(
        key: buttonKey,
        height: 58,
        padding: EdgeInsets.zero,
        radius: 22,
        onTap: enabled ? onTap : null,
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppGlassColors.aqua,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: AppGlassColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

class GlassFormCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const GlassFormCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: padding,
      radius: 22,
      child: Theme(
        data: glassFormTheme(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class GlassCheckTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final String title;
  final String? subtitle;
  final Widget? leading;

  const GlassCheckTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      checkboxShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
      secondary: leading,
      title: Text(
        title,
        style: const TextStyle(
          color: AppGlassColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(
                color: AppGlassColors.inkMuted,
                fontSize: 12,
              ),
            ),
      value: value,
      activeColor: AppGlassColors.aqua,
      checkColor: AppGlassColors.pageTop,
      side: const BorderSide(color: AppGlassColors.inkMuted),
      onChanged: onChanged,
    );
  }
}

class GlassRadioTile<T> extends StatelessWidget {
  final T value;
  final String label;
  final String? description;

  const GlassRadioTile({
    super.key,
    required this.value,
    required this.label,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<T>(
      dense: true,
      title: Text(
        label,
        style: const TextStyle(
          color: AppGlassColors.ink,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
      subtitle: description == null
          ? null
          : Text(
              description!,
              style: const TextStyle(
                fontSize: 12,
                color: AppGlassColors.inkMuted,
              ),
            ),
      value: value,
      activeColor: AppGlassColors.aqua,
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppGlassColors.aqua
            : AppGlassColors.inkMuted,
      ),
    );
  }
}

ThemeData glassFormTheme(BuildContext context) {
  final base = Theme.of(context);

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppGlassColors.ink,
      displayColor: AppGlassColors.ink,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: false,
      fillColor: Colors.transparent,
      labelStyle: TextStyle(
        color: AppGlassColors.inkMuted,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: TextStyle(
        color: AppGlassColors.aqua,
        fontWeight: FontWeight.w800,
      ),
      hintStyle: TextStyle(
        color: AppGlassColors.inkMuted,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: AppGlassColors.inkMuted,
      suffixIconColor: AppGlassColors.inkMuted,
      errorStyle: TextStyle(
        color: AppGlassColors.rose,
        fontWeight: FontWeight.w700,
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppGlassColors.aqua,
      selectionColor: Color(0x3367E8D4),
      selectionHandleColor: AppGlassColors.aqua,
    ),
  );
}
