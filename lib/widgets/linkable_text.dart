import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_glass.dart';

/// Renders shared text with tappable web links while preserving its wording.
class LinkableText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const LinkableText(this.text, {super.key, required this.style});

  @override
  State<LinkableText> createState() => _LinkableTextState();
}

class _LinkableTextState extends State<LinkableText> {
  static final _webLinks = RegExp(
    r'''(?<![\w@/])(?:https?://|www\.)[^\s<>"‘’“”]+''',
    caseSensitive: false,
  );
  static const _openingBrackets = {')': '(', ']': '[', '}': '{'};
  static const _linkStyle = TextStyle(
    color: AppGlassColors.aqua,
    decoration: TextDecoration.underline,
    decorationColor: AppGlassColors.aqua,
  );

  late List<TextSpan> _spans;

  @override
  void initState() {
    super.initState();
    _spans = _buildSpans();
  }

  @override
  void didUpdateWidget(covariant LinkableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text) return;
    _disposeRecognizers();
    _spans = _buildSpans();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final span in _spans) {
      span.recognizer?.dispose();
    }
  }

  List<TextSpan> _buildSpans() {
    final text = widget.text;
    final spans = <TextSpan>[];
    var start = 0;
    for (final match in _webLinks.allMatches(text)) {
      final label = _stripTrailingPunctuation(match[0]!);
      final startsWithWww = label.toLowerCase().startsWith('www.');
      final uri = Uri.tryParse(startsWithWww ? 'https://$label' : label);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        continue;
      }

      if (start < match.start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final recognizer = TapGestureRecognizer()..onTap = () => _open(uri);
      spans.add(TextSpan(
        text: label,
        style: _linkStyle,
        recognizer: recognizer,
        mouseCursor: SystemMouseCursors.click,
      ));
      start = match.start + label.length;
    }

    if (spans.isNotEmpty && start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return spans;
  }

  // Keep punctuation in the displayed text, but leave it out of the URL.
  // A balanced closing bracket may be part of the URL itself.
  static String _stripTrailingPunctuation(String text) {
    var end = text.length;
    final extraClosers = <String, int>{};
    while (end > 0) {
      final last = text[end - 1];
      if (".,;:!?'".contains(last)) {
        end--;
        continue;
      }
      final opening = _openingBrackets[last];
      if (opening == null) break;
      final count = extraClosers.putIfAbsent(
        last,
        () => last.allMatches(text).length - opening.allMatches(text).length,
      );
      if (count <= 0) break;
      extraClosers[last] = count - 1;
      end--;
    }
    return text.substring(0, end);
  }

  Future<void> _open(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // The operating system may not have an app that can open this link.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this link.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_spans.isEmpty) return Text(widget.text, style: widget.style);
    return Text.rich(TextSpan(children: _spans), style: widget.style);
  }
}
