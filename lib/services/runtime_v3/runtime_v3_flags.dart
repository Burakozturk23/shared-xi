class RuntimeV3Flags {
  RuntimeV3Flags._();

  /// Production default: Runtime V3 is ON.
  static const bool enabled = bool.fromEnvironment(
    'LINKBALL_SQLITE_V3',
    defaultValue: true,
  );

  /// Production default: migrated gameplay controllers use Runtime V3.
  /// Player/Club UI models still come from Repository until the V3 model bridge.
  static const bool gameplayEnabled = bool.fromEnvironment(
    'LINKBALL_SQLITE_GAMEPLAY_V3',
    defaultValue: true,
  );

  static const bool parityLog = bool.fromEnvironment(
    'LINKBALL_SQLITE_PARITY',
    defaultValue: false,
  );
}
