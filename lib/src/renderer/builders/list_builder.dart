import 'package:flutter/material.dart';

import '../../config/style_sheet.dart';
import '../../parser/ast/html_nodes.dart';
import '../../parser/ast/markdown_node.dart';
import '../../parser/plugins/admonition_plugin.dart';
import '../../parser/plugins/artifact_plugin.dart';
import '../../parser/plugins/mermaid_plugin.dart';
import '../../parser/plugins/thinking_plugin.dart';
import '../../parser/plugins/tool_call_plugin.dart';
import '../widget_builder.dart';

/// Builder for list nodes
class ListBuilder extends MarkdownWidgetBuilder {
  /// Creates a new list builder
  const ListBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is ListNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final listNode = node as ListNode;
    final indent = styleSheet.listIndent ?? 24.0;

    final listItems = <Widget>[];
    for (var i = 0; i < listNode.items.length; i++) {
      final item = listNode.items[i];
      final index = listNode.ordered ? listNode.startIndex + i : null;

      listItems.add(
        _buildListItem(
          item,
          index,
          indent,
          styleSheet,
          context,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: listItems,
    );
  }

  Widget _buildListItem(
    ListItemNode item,
    int? index,
    double indent,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    // Build marker (bullet or number)
    Widget marker;
    if (item.checked != null) {
      // Task list item
      marker = Icon(
        item.checked! ? Icons.check_box : Icons.check_box_outline_blank,
        size: 20,
      );
    } else if (index != null) {
      // Ordered list
      marker = Text(
        '$index. ',
        style: styleSheet.listBulletStyle,
      );
    } else {
      // Unordered list
      marker = Text(
        '• ',
        style: styleSheet.listBulletStyle,
      );
    }

    // The item's first line is inline content; what follows it — a nested
    // list, or a paragraph, quote, code block or table indented under the
    // item — is a block of its own and goes on its own line below.
    final inlineChildren = <MarkdownNode>[];
    final blockChildren = <MarkdownNode>[];
    for (final child in item.children) {
      if (blockChildren.isEmpty && !_isBlock(child)) {
        if (child is TextNode && child.content.isEmpty) continue;
        inlineChildren.add(child);
      } else {
        blockChildren.add(child);
      }
    }

    // Render item content using inlineRenderer from context
    final inlineRenderer = context.inlineRenderer;
    Widget? content;
    if (inlineChildren.isNotEmpty && inlineRenderer != null) {
      content = inlineRenderer(inlineChildren, styleSheet.textStyle);
    } else if (inlineChildren.isNotEmpty) {
      // Fallback
      final text = _extractText(inlineChildren);
      content = Text(text, style: styleSheet.textStyle);
    }

    final blockRenderer = context.blockRenderer;
    final contentChildren = <Widget>[
      if (content != null) content,
      for (final child in blockChildren)
        if (child is ListNode)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: build(
              child,
              styleSheet,
              context.copyWith(listLevel: context.listLevel + 1),
            ),
          )
        else if (blockRenderer != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: blockRenderer([child]),
          )
        else if (inlineRenderer != null)
          inlineRenderer([child], styleSheet.textStyle)
        else
          Text(_extractText([child]), style: styleSheet.textStyle),
    ];

    return Padding(
      padding: EdgeInsets.only(left: context.listLevel * indent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          marker,
          const SizedBox(width: 4),
          Expanded(
            child: contentChildren.length == 1
                ? contentChildren.single
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: contentChildren,
                  ),
          ),
        ],
      ),
    );
  }

  static bool _isBlock(MarkdownNode node) =>
      node is ListNode ||
      node is ParagraphNode ||
      node is BlockquoteNode ||
      node is CodeBlockNode ||
      node is TableNode ||
      node is HeaderNode ||
      node is HorizontalRuleNode ||
      node is BlockMathNode ||
      node is HtmlBlockNode ||
      node is FootnoteDefinitionNode ||
      node is DetailsNode ||
      node is AdmonitionNode ||
      node is MermaidDiagramNode ||
      node is ThinkingNode ||
      node is ArtifactNode ||
      node is ToolCallNode;

  String _extractText(List<MarkdownNode> nodes) {
    final buffer = StringBuffer();
    for (final node in nodes) {
      if (node is TextNode) {
        buffer.write(node.content);
      } else if (node is HardBreakNode) {
        buffer.write('\n');
      }
    }
    return buffer.toString();
  }
}
