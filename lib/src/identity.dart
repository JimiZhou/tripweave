import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TripRole { traveler, admin }

class TripIdentity {
  const TripIdentity({
    required this.displayName,
    required this.role,
    required this.signedInAt,
  });

  final String displayName;
  final TripRole role;
  final DateTime signedInAt;

  bool get isAdmin => role == TripRole.admin;
  String get initial {
    final trimmed = displayName.trim();
    return trimmed.isEmpty ? '旅' : String.fromCharCode(trimmed.runes.first);
  }

  factory TripIdentity.fromJson(Map<String, dynamic> json) => TripIdentity(
    displayName: '${json['displayName'] ?? ''}',
    role: TripRole.values.asNameMap()['${json['role']}'] ?? TripRole.traveler,
    signedInAt:
        DateTime.tryParse('${json['signedInAt']}') ?? DateTime.now(),
  );

  Map<String, Object> toJson() => {
    'displayName': displayName,
    'role': role.name,
    'signedInAt': signedInAt.toIso8601String(),
  };
}

/// Persists the device-local identity and the admin passcode digest.
///
/// TripWeave stays local-first: there is no account server. "Login" means a
/// device profile that gates the workspace, and "admin" is whoever configured
/// the admin passcode on this device (typically the person provisioning model
/// presets for a family member or a kiosk deployment).
class IdentityStore {
  static const _identityKey = 'tripweave.identity.v1';
  static const _passcodeKey = 'tripweave.admin-passcode.v1';

  Future<TripIdentity?> loadIdentity() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_identityKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return TripIdentity.fromJson(
        (jsonDecode(encoded) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveIdentity(TripIdentity identity) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_identityKey, jsonEncode(identity.toJson()));
  }

  Future<void> clearIdentity() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_identityKey);
  }

  Future<bool> hasAdminPasscode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_passcodeKey)?.isNotEmpty == true;
  }

  Future<void> saveAdminPasscode(String passcode) async {
    final preferences = await SharedPreferences.getInstance();
    final salt = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await preferences.setString(_passcodeKey, '$salt:${_digest(passcode, salt)}');
  }

  Future<bool> verifyAdminPasscode(String passcode) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_passcodeKey);
    if (stored == null || !stored.contains(':')) return false;
    final salt = stored.substring(0, stored.indexOf(':'));
    final expected = stored.substring(stored.indexOf(':') + 1);
    return _digest(passcode, salt) == expected;
  }

  String _digest(String passcode, String salt) =>
      sha256.convert(utf8.encode('$salt::tripweave::$passcode')).toString();
}
