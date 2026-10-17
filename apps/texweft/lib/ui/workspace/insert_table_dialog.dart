import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_widgets.dart';

Future<({int rows, int columns})?> showInsertTableDialog(
  BuildContext context,
) => showDialog<({int rows, int columns})>(
  context: context,
  builder: (_) => const _InsertTableDialog(),
);

class _InsertTableDialog extends StatefulWidget {
  const _InsertTableDialog();
  @override
  State<_InsertTableDialog> createState() => _InsertTableDialogState();
}

class _InsertTableDialogState extends State<_InsertTableDialog> {
  final _form = GlobalKey<FormState>();
  final _rows = TextEditingController(text: '3');
  final _columns = TextEditingController(text: '3');
  @override
  void initState() {
    super.initState();
    _rows.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
  }

  void _insert() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, (
        rows: int.parse(_rows.text),
        columns: int.parse(_columns.text),
      ));
    }
  }

  @override
  void dispose() {
    _rows.dispose();
    _columns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: '插入表格',
    width: 380,
    actions: [
      AppButton(label: '取消', onPressed: () => Navigator.pop(context)),
      AppButton(label: '插入', icon: 'grid', primary: true, onPressed: _insert),
    ],
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('设置表格大小，第一行为表头。', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 20),
          for (final item in [
            (_rows, '行数', 'table-rows', 100),
            (_columns, '列数', 'table-columns', 20),
          ]) ...[
            TextFormField(
              key: ValueKey(item.$3),
              controller: item.$1,
              autofocus: item.$1 == _rows,
              keyboardType: TextInputType.number,
              textInputAction: item.$1 == _rows
                  ? TextInputAction.next
                  : TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: item.$2,
                helperText: item.$1 == _rows ? '1–100 行，包含表头' : '1–20 列',
              ),
              validator: (text) {
                final count = int.tryParse(text ?? '');
                return count == null || count < 1 || count > item.$4
                    ? '请输入 1–${item.$4} 之间的整数'
                    : null;
              },
              onFieldSubmitted: (_) {
                if (item.$1 == _columns) _insert();
              },
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    ),
  );
}
