import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final path =
        Platform.environment['E_READER_REPORT_PATH'] ??
        'build/device-performance.json';
    final output = File(path);
    await output.parent.create(recursive: true);
    await output.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
  },
);
