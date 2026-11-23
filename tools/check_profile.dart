import 'dart:convert';
import 'dart:io';

/// Checks a local example profile before launching Flutter. TRTC authenticates
/// the UserSig when the participant joins the room.
Future<String?> checkProfile(File file) async {
  if (!await file.exists()) {
    return 'Create the profile from the matching template in config/.';
  }
  final profile = jsonDecode(await file.readAsString());
  if (profile is! Map<String, dynamic>) return 'Expected a JSON object.';
  final appId = int.tryParse('${profile['SDK_APP_ID']}');
  final user = profile['USER_ID'];
  if (appId == null || appId < 1 || appId > 0xffffffff) {
    return 'Enter a valid SDK_APP_ID.';
  }
  if (user is! String || !RegExp(r'^[A-Za-z0-9_-]{1,32}$').hasMatch(user)) {
    return 'Enter a valid USER_ID.';
  }
  final sig = profile['USER_SIG'];
  if (sig is! String || sig.isEmpty || sig.length > 8192) {
    return 'Enter a Tencent UserSig in USER_SIG.';
  }

  final compressed = base64.decode(
    sig.replaceAll('*', '+').replaceAll('-', '/').replaceAll('_', '='),
  );
  final bytes = <int>[];
  await for (final chunk in zlib.decoder.bind(Stream.value(compressed))) {
    if (bytes.length + chunk.length > 32768) return 'Invalid UserSig payload.';
    bytes.addAll(chunk);
  }
  final payload = jsonDecode(utf8.decode(bytes));
  if (payload is! Map<String, dynamic> || payload['TLS.ver'] != '2.0') {
    return 'Expected a Tencent v2 UserSig.';
  }
  if (payload['TLS.sdkappid'] != appId || payload['TLS.identifier'] != user) {
    return 'The UserSig must match SDK_APP_ID and USER_ID.';
  }
  final issued = payload['TLS.time'];
  final lifetime = payload['TLS.expire'];
  if (issued is! int || lifetime is! int) return 'Invalid UserSig expiry.';
  final expiry = issued + lifetime;
  if (expiry <= DateTime.now().millisecondsSinceEpoch ~/ 1000) {
    return 'The UserSig has expired.';
  }
  final stated = int.tryParse('${profile['TOKEN_EXPIRES_AT'] ?? 0}');
  if (stated != 0 && stated != expiry) {
    return 'TOKEN_EXPIRES_AT must match the UserSig expiry.';
  }
  return null;
}

Future<void> main(List<String> arguments) async {
  String? error;
  try {
    error = arguments.length == 1
        ? await checkProfile(File(arguments.single))
        : 'Pass the path to a Tencent profile.';
  } on FormatException {
    error = 'Invalid JSON or UserSig encoding.';
  } on IOException {
    error = 'Could not read the profile or decode its UserSig.';
  }
  if (error != null) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
