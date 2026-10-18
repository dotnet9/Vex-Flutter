import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Windows user data is stored directly in the Vex roaming directory',
    (tester) async {
      final roaming = Platform.environment['APPDATA'];
      expect(roaming, isNotNull);
      final directory = await getApplicationSupportDirectory();

      expect(p.equals(directory.path, p.join(roaming!, 'Vex')), isTrue);
    },
    skip: !Platform.isWindows,
  );
}
