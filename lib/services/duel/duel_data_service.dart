import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../../models/duel_data_catalog.dart';

/// Lazy additive package; a broken package hides duel criteria, not other modes.
class DuelDataService {
  DuelDataService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  static final instance = DuelDataService();
  final AssetBundle _bundle;
  DuelDataCatalog? _catalog;
  Future<DuelDataCatalog?>? _inFlight;
  String? lastError;

  Future<DuelDataCatalog?> load() {
    if (_catalog != null) return Future.value(_catalog);
    return _inFlight ??= _load().whenComplete(() { _inFlight = null; });
  }

  Future<DuelDataCatalog?> _load() async {
    try {
      final manifest = jsonDecode(await _bundle.loadString('assets/data/duel/manifest.json')) as Map;
      final base = jsonDecode(await _bundle.loadString('assets/runtime/linkball_game_data_v4_manifest.json')) as Map;
      final bytes = await _bundle.load('assets/data/duel/runtime.json');
      final raw = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
      if (manifest['schemaVersion'] != 1 || manifest['bytes'] != raw.length ||
          manifest['sha256'] != sha256.convert(raw).toString() ||
          manifest['baseDatabaseSha256'] != (base['database'] as Map)['sha256']) {
        throw const FormatException('Duel package/base integrity mismatch');
      }
      final catalog = DuelDataCatalog.fromJson(jsonDecode(utf8.decode(raw)) as Map<String, dynamic>);
      if (catalog.version != manifest['version'] || catalog.cutoff != manifest['cutoff'] ||
          catalog.baseDatabaseSha256 != manifest['baseDatabaseSha256']) {
        throw const FormatException('Duel version mismatch');
      }
      _catalog = catalog;
      lastError = null;
      return catalog;
    } catch (error) {
      lastError = error.toString();
      return null;
    }
  }
}
