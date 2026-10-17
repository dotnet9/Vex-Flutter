import 'package:flutter/material.dart';

/// Source coordinates are captured before a context menu takes keyboard focus.
final class MarkdownContextRequest {
  const MarkdownContextRequest({
    required this.offset,
    required this.position,
    this.tableRow,
    this.tableColumn,
    this.readOnly = false,
  });
  final int offset;
  final Offset position;
  final int? tableRow, tableColumn;
  final bool readOnly;
}
