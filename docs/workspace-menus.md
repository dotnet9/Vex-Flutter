# Workspace Menus

The native app shares a typed command tree between Windows/Linux flyouts,
macOS system menus, and phone/tablet touch sheets. The seven categories are
File, Edit, Paragraph, Format, View, Tools, and Help.

- macOS uses native window chrome and Command shortcuts. About, Preferences,
  Services, Hide, and Quit live in the application menu. Quit follows the same
  unsaved-document and recovery checks as closing the window.
- Phone and tablet menus navigate one level at a time in a bottom sheet, with a
  fixed title, Back and Close controls. Only the item list scrolls. System Back
  returns to the preceding menu level before dismissing the sheet.
- Phone layout commands expose single views; tablet layout commands expose at
  most two panes. Desktop menus retain all eight workspace arrangements.
- Submenu, dropdown, and window-control glyphs use the same 16px size.
- Paragraph conversion replaces existing heading/list/task/quote prefixes and
  applies to all selected lines. Repeating a paragraph style toggles it off.
- Inline formatting toggles around the selection. Formula, code, rule, table,
  Mermaid, and footnote insertion preserve document line endings and share
  one-step undo with source/instant editing.
- Clipboard operations capture the original document and selection; async
  completion cannot paste or cut in another document or a changed selection.

Automated coverage: `workspace_menu_test.dart`, `formatting_commands_test.dart`,
and the native Windows integration capture `integration_test/menus_test.dart`.
The macOS menu structure and shortcuts are widget-tested on this Windows host;
native macOS appearance still requires a macOS runner/device check.

## Tables

Paragraph > Table and the table-cell context menu share the same commands:
insert, move and delete rows/columns; set column alignment; copy, format and
delete the table. Header rows cannot move into the body, and the final column
cannot be deleted. Every structural change is one undo step and restores the
selection to the affected cell. Escaped pipes, code spans and CRLF are retained.

Desktop cells use an anchored secondary-click menu. Phone/tablet long-press
opens the fixed-header touch sheet. Reading mode only permits copying a table.
Commands captured before a document change or switch cannot modify new content.
Coverage: `table_commands_test.dart`, `test/table_menu_test.dart`, and native
Windows screenshots in `integration_test/table_menu_test.dart`.
