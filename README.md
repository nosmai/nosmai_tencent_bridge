# Nosmai Tencent Bridge for Flutter

Publish the Nosmai camera, with beauty effects and filters, to a Tencent RTC (TRTC) room on Android or iOS. If your app already uses TRTC, replace the **host’s local camera preview and room start/stop calls**. Keep your existing Tencent authentication and audience screens. Viewers receive the effects in the video and can use a standard TRTC video view.

## Install

Use Flutter 3.29 or later. The bridge supports Android API 24+ with OpenGL ES 3.0 and iOS 15+ with CocoaPods. The Flutter package is `nosmai_tencent_live` and includes the Nosmai and Tencent SDK dependencies.

Add the bridge to your app’s `pubspec.yaml`. Your development machine and CI need Git access to the Nosmai repository.

```yaml
dependencies:
  nosmai_tencent_live:
    git:
      url: https://github.com/nosmai/nosmai_tencent_bridge.git
      path: packages/nosmai_tencent_live
```

Run `flutter pub get` from your app directory and rebuild the app. [Package reference](packages/nosmai_tencent_live/README.md)

## Initialize, preview and go live

The host can preview the camera and try effects before joining a room. A **Nosmai license** starts the camera. A **Tencent UserSig** authenticates the host when they tap **Go live**.

```dart
import 'package:flutter/material.dart';
import 'package:nosmai_tencent_live/nosmai_tencent_live.dart';
```

### 1. Initialize Nosmai on the host

Use the bridge as your app’s Nosmai initialization entry point. On Android, it prepares the shared GPU context before Nosmai opens the camera. Supply a license for the Android application ID or iOS bundle ID.

```dart
Future<void> initializeHost({
  required String androidLicenseKey,
  required String iosLicenseKey,
}) async {
  final permissions = await NosmaiTencentLive.requestPermissions();
  if (!permissions.camera) throw StateError('Camera access is required.');
  await NosmaiTencentLive.initialize(
    androidLicenseKey: androidLicenseKey,
    iosLicenseKey: iosLicenseKey,
  );
}
```

### 2. Show the local preview

After initialization succeeds, mount one `NosmaiCameraPreview` in your host screen’s `State`. Enable **Go live** when `cameraReady` becomes true. Keep the preview mounted throughout the broadcast.

```dart
bool cameraReady = false;

Widget buildLocalPreview() => SizedBox(
  height: 300,
  child: NosmaiCameraPreview(
    onInitialized: () {
      if (mounted) setState(() => cameraReady = true);
    },
    onError: (message) {
      if (!mounted) return;
      setState(() => cameraReady = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    },
  ),
);
```

### 3. Publish when the host joins

Use your existing Tencent SDKAppID, room ID, user ID and server-issued UserSig. `NosmaiLiveBroadcaster.start()` enables Tencent custom capture, enters the room as the host and publishes the preview. It replaces the host’s `TRTCCloud.enterRoom` call. The default broadcast uses the microphone as well as the camera.

```dart
NosmaiLiveBroadcaster? broadcaster;

Future<void> goLive({
  required int sdkAppId,
  required int roomId,
  required String userId,
  required String userSig,
}) async {
  if (!cameraReady || broadcaster != null) return;
  final live = NosmaiLiveBroadcaster(
    credentials: NosmaiLiveCredentials(
      sdkAppId: sdkAppId,
      userId: userId,
      userSig: userSig,
    ),
    room: NosmaiLiveRoom(roomId),
  );
  broadcaster = live;
  try {
    await live.start();
  } catch (_) {
    if (identical(broadcaster, live)) {
      broadcaster = null;
      live.dispose();
    }
    rethrow;
  }
}
```

A foreground host with video enabled completes `start()` after the first frame is submitted. For a camera-only broadcast, pass `publishAudio: false`. If your app uses string room IDs, use `NosmaiLiveRoom.named(roomName)` on both devices. [Host screen example](lib/nosmai_studio.dart)

### 4. Watch and leave

Your existing Tencent viewer joins the same room with its own user ID and UserSig. A viewer needs no Nosmai license or camera permission. For a new audience screen, the package also provides `NosmaiLiveViewer` and `NosmaiLiveViewerView`. [Viewer example](lib/viewer_page.dart)

On the host, call `stop()` to leave the room and `dispose()` to release the broadcaster. This lets the host keep trying effects locally. When the camera screen closes, also call `await NosmaiTencentLive.effects.endCameraSession()` and remove the preview.

```dart
Future<void> endLive() async {
  final live = broadcaster;
  if (live == null) return;
  await live.stop();
  if (identical(broadcaster, live)) {
    live.dispose();
    broadcaster = null;
  }
}
```

## Camera controls

- Apply effects before or during a broadcast. For example, `await NosmaiTencentLive.effects.applySkinSmoothing(0.6)` changes both the preview and the outgoing video.
- Use `await NosmaiTencentLive.effects.switchCamera()` to flip cameras. Use `broadcaster?.setMicMuted(true)` or `broadcaster?.setVideoMuted(true)` to mute each stream independently.
- The default encoder preset targets 540p at 24 FPS. Pass `video: NosmaiLiveVideoConfig.low` for 360p at 15 FPS or `video: NosmaiLiveVideoConfig.hd` for 720p at 30 FPS.

## Platform notes

- **Android** uses shared GPU textures when available and falls back to I420 frames. Check `broadcaster?.stats.transport` to see which path is active. The plugin declares camera, microphone and network permissions in its manifest.
- **iOS** sends processed pixel buffers to TRTC. Include `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` in your app’s `Info.plist` with descriptions of how the host uses the camera and microphone.
- **App lifecycle.** By default the broadcaster pauses video and microphone capture for the room when the app goes into the background and resumes publishing in the same room on return.
- **Device verification.** A Pixel 5 and iPhone SE (2nd generation) each hosted a 720p, 15 FPS stream. The viewer received filter changes and new frames after the host returned from the background.

Use of the Nosmai and Tencent RTC SDKs is subject to their respective licenses and service terms.
