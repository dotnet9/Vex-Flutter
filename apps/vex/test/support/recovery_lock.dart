import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final directory = Directory('${arguments.single}/recovery-sessions/active');
  await directory.create(recursive: true);
  final lock = await File('${directory.path}/session.lock')
      .open(mode: FileMode.append);
  await lock.lock(FileLock.exclusive);
  await File('${directory.path}/recovery-v1.json').writeAsString(
    jsonEncode([
      {'name': 'active.md', 'text': 'another window'},
    ]),
    flush: true,
  );
  stdout.writeln('ready');
  await stdin.first;
  await lock.close();
}
