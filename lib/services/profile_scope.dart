/// Stable IDs isolate storage from editable profile names. The primary profile
/// keeps every legacy filename/key so existing installs continue to work.
class ProfileScope {
  static String id = 'primary';
  static bool get isPrimary => id == 'primary';
  static String key(String legacyKey) =>
      isPrimary ? legacyKey : 'profile_${id}_$legacyKey';
  static String filePrefix(String legacyPrefix) =>
      isPrimary ? legacyPrefix : '${legacyPrefix}_$id';
}
