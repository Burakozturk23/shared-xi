import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gzipped V4 SQLite asset decompresses to manifest bytes and sha256', () {
    final manifest =
        jsonDecode(
              File(
                'assets/runtime/linkball_game_data_v4_manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final dbInfo = manifest['database'] as Map<String, dynamic>;
    final expectedBytes = (dbInfo['bytes'] as num).toInt();
    final expectedSha = dbInfo['sha256'] as String;

    final gzFile = File('assets/runtime/linkball_game_data_v4.sqlite.gz');
    expect(gzFile.existsSync(), isTrue);
    expect(File('assets/runtime/linkball_game_data_v4.sqlite').existsSync(), isFalse);

    final decompressed = gzip.decode(gzFile.readAsBytesSync());
    expect(decompressed.length, expectedBytes);
    expect(sha256.convert(decompressed).toString(), expectedSha);
  });
}
