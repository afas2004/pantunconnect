import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lightweight markdown renderer for AI chat bubbles - no package dependency.
///
/// Handles the subset Gemini actually produces: **bold**, *italic*, `# headers`,
/// `> blockquotes` (rendered as elegant verse cards - pantun lines usually arrive as quotes),
/// numbered/bulleted lists, and `---` dividers. Anything else renders as a plain paragraph.
class MarkdownLite extends StatelessWidget {
  const MarkdownLite(this.text, {super.key, this.baseStyle});

  final String text;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) {
    final style = baseStyle ?? const TextStyle(color: Colors.black87, fontSize: 14.5, height: 1.45);
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final blocks = <Widget>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Blank line -> small gap (collapse runs of blanks into one).
      if (trimmed.isEmpty) {
        if (blocks.isNotEmpty) blocks.add(const SizedBox(height: 8));
        while (i < lines.length && lines[i].trim().isEmpty) {
          i++;
        }
        continue;
      }

      // Horizontal rule.
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        blocks.add(Divider(color: Colors.grey.shade300, height: 20, thickness: 1));
        i++;
        continue;
      }

      // Blockquote group (consecutive `>` lines) - the pantun verses.
      if (trimmed.startsWith('>')) {
        final quoteLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          quoteLines.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        blocks.add(_QuoteBlock(lines: quoteLines, baseStyle: style));
        continue;
      }

      // Header.
      final headerMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (headerMatch != null) {
        final level = headerMatch.group(1)!.length;
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text.rich(
            TextSpan(children: _inlineSpans(headerMatch.group(2)!)),
            style: style.copyWith(
              fontSize: level <= 2 ? 17.0 : 15.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryAccentStrong,
            ),
          ),
        ));
        i++;
        continue;
      }

      // Numbered list item.
      final numMatch = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
      if (numMatch != null) {
        blocks.add(_ListItem(
          marker: '${numMatch.group(1)}.',
          content: numMatch.group(2)!,
          baseStyle: style,
        ));
        i++;
        continue;
      }

      // Bulleted list item.
      final bulletMatch = RegExp(r'^[-*]\s+(.*)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        blocks.add(_ListItem(marker: '•', content: bulletMatch.group(1)!, baseStyle: style));
        i++;
        continue;
      }

      // Plain paragraph.
      blocks.add(Text.rich(TextSpan(children: _inlineSpans(trimmed)), style: style));
      i++;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: blocks);
  }
}

/// Inline **bold** / *italic* spans (bold parsed first so `**` never reads as two italics).
List<InlineSpan> _inlineSpans(String text) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
  var index = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > index) {
      spans.add(TextSpan(text: text.substring(index, match.start)));
    }
    if (match.group(1) != null) {
      spans.add(TextSpan(text: match.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
    } else {
      spans.add(TextSpan(text: match.group(2), style: const TextStyle(fontStyle: FontStyle.italic)));
    }
    index = match.end;
  }
  if (index < text.length) {
    spans.add(TextSpan(text: text.substring(index)));
  }
  return spans;
}

/// Blockquote rendered as a soft verse card: tinted background, accent bar, italic lines.
class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.lines, required this.baseStyle});

  final List<String> lines;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.softLavender.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: AppColors.softBlue, width: 3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines)
            line.trim().isEmpty
                ? const SizedBox(height: 6)
                : Text.rich(
                    TextSpan(children: _inlineSpans(line)),
                    style: baseStyle.copyWith(fontStyle: FontStyle.italic, height: 1.55),
                  ),
        ],
      ),
    );
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({required this.marker, required this.content, required this.baseStyle});

  final String marker;
  final String content;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(marker, style: baseStyle.copyWith(fontWeight: FontWeight.w700, color: AppColors.primaryAccentStrong)),
          ),
          Expanded(child: Text.rich(TextSpan(children: _inlineSpans(content)), style: baseStyle)),
        ],
      ),
    );
  }
}
