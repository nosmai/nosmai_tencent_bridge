import 'package:nosmai_tencent_live/nosmai_tencent_live.dart';

/// Only short-lived test credentials reach the app. Never add SecretKey here.
class AppCredentials {
  const AppCredentials({
    required this.sdkAppId,
    required this.userId,
    required this.userSig,
    this.expiresAt = 0,
  });

  const AppCredentials.fromEnvironment()
      : sdkAppId = const int.fromEnvironment('SDK_APP_ID'),
        userId = const String.fromEnvironment('USER_ID'),
        userSig = const String.fromEnvironment('USER_SIG'),
        expiresAt = const int.fromEnvironment('TOKEN_EXPIRES_AT');

  final int sdkAppId;
  final String userId;
  final String userSig;
  final int expiresAt;

  NosmaiLiveCredentials toLive() =>
      NosmaiLiveCredentials(sdkAppId: sdkAppId, userId: userId, userSig: userSig);

  String? validate({DateTime? now}) {
    if (sdkAppId <= 0 || sdkAppId > 4294967295) {
      return 'Set SDK_APP_ID to your Tencent application ID and rebuild the app.';
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{1,32}$').hasMatch(userId)) {
      return 'USER_ID must contain 1–32 letters, numbers, underscores or hyphens.';
    }
    if (userSig.trim().isEmpty || userSig.contains('PASTE_')) {
      return 'Set USER_SIG to the Tencent UserSig issued for USER_ID and rebuild the app.';
    }
    final seconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    if (expiresAt > 0 && seconds >= expiresAt) {
      return 'This UserSig has expired. Set USER_SIG to a fresh token and rebuild the app.';
    }
    return null;
  }
}

int? parseRoomId(String input) {
  final text = input.trim();
  if (!RegExp(r'^[0-9]+$').hasMatch(text)) return null;
  final value = int.tryParse(text);
  return value != null && value >= 1 && value <= 4294967294 ? value : null;
}
