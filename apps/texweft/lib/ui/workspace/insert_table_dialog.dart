import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
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
    title: context.l10n.insertTable,
    width: 380,
    actions: [
      AppButton(
        label: context.l10n.cancel,
        onPressed: () => Navigator.pop(context),
      ),
      AppButton(
        label: context.l10n.insert,
        icon: 'grid',
        primary: true,
        onPressed: _insert,
      ),
    ],
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.tableSizeHint,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),
          for (final item in [
            (_rows, context.l10n.rows, 'table-rows', 100),
            (_columns, context.l10n.columns, 'table-columns', 20),
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
                helperText: item.$1 == _rows
                    ? context.l10n.tableRowsHint
                    : context.l10n.tableColumnsHint,
              ),
              validator: (text) {
                final count = int.tryParse(text ?? '');
                return count == null || count < 1 || count > item.$4
                    ? context.l10n.integerRange(item.$4)
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
