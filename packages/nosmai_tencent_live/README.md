# Nosmai Tencent Bridge for Flutter

`nosmai_tencent_live` publishes Nosmai’s processed camera frames to Tencent RTC on Android and iOS. The repository guide covers installation, host initialization, local preview, publishing and the two-phone example. [Integration guide](../../README.md)

## Broadcaster

Use `NosmaiLiveBroadcaster` on the host. Its `start()` and `stop()` methods manage the host’s Tencent room membership. Listen to `state`, `stats`, `warning` and `error` to update your UI. Await `stop()` before starting a new session and call `dispose()` when finished. [Host example](../../lib/nosmai_studio.dart)

- `setMicMuted(bool)` and `setVideoMuted(bool)` control the two streams independently. Set `publishAudio: false` in the constructor for a video-only broadcast.
- `switchCamera()` flips the camera. `setMaxFps(int)` changes the publishing frame-rate cap.
- `stats.framesFromNosmai` counts processed input frames and `stats.framesSent` counts frames handed to Tencent. Check the viewer’s receiving statistics to confirm delivery.
- `stats.transport` reports `texture` or `i420` on Android and `pixelBuffer` on iOS.

## Viewer

An existing TRTC audience screen can receive the filtered stream directly. For a new screen, initialize a `NosmaiLiveViewer` with the viewer’s own credentials and the host’s room ID. Use `hostUserId` to select a particular broadcaster in a room with multiple hosts.

```dart
final viewer = NosmaiLiveViewer(
  credentials: NosmaiLiveCredentials(
    sdkAppId: sdkAppId,
    userId: viewerUserId,
    userSig: viewerUserSig,
  ),
  room: NosmaiLiveRoom(roomId),
);
await viewer.start();
```

Place `NosmaiLiveViewerView(viewer: viewer)` in the widget tree. Use `viewer.hasVideo` to check for a first rendered frame and `viewer.setSpeakerMuted(true)` to mute playback. Await `viewer.stop()` and call `viewer.dispose()` when leaving. [Audience screen example](../../lib/viewer_page.dart)

## Video settings

The built-in presets set the target resolution, frame rate and bitrate.

- `NosmaiLiveVideoConfig.low` targets 360 × 640 at 15 FPS and 550 kbps.
- `NosmaiLiveVideoConfig.standard` is the default. It targets 540 × 960 at 24 FPS and 1,200 kbps.
- `NosmaiLiveVideoConfig.hd` targets 720 × 1280 at 30 FPS and 1,800 kbps.

Use the `NosmaiLiveVideoConfig` constructor for a custom resolution, FPS or bitrate. Thermal adaptation is enabled by default. On devices that report thermal status, the publishing cap drops to 15 FPS under serious or severe thermal pressure and to 10 FPS under critical pressure. [Video configuration](lib/src/video_config.dart)

## Troubleshooting

- **The host preview works but the viewer is waiting.** Check that both users have the same SDKAppID and room, distinct user IDs and valid UserSigs. Confirm the host has reached `isLive` and its `stats.framesSent` counter is increasing.
- **`no_video`.** The host joined but the bridge timed out waiting for its first frame. Keep the host’s `NosmaiCameraPreview` mounted and enable **Go live** after `onInitialized`.
- **`session_in_use`.** Another bridge session owns the Tencent engine. Await the previous broadcaster’s or viewer’s `stop()` before starting the next one.
- **`license_rejected` or `missing_license_key`.** Check the host’s Nosmai license against the Android application ID or iOS bundle ID. Initialize it with `NosmaiTencentLive.initialize` before showing the preview.
- **`permission_denied`.** A broadcast with audio needs microphone permission. For camera-only publishing, set `publishAudio: false`.
- **Unexpected I420 transport on Android.** Call `NosmaiTencentLive.initialize` before any direct call to `NosmaiFlutter.initialize` so the bridge can prepare the shared GPU context. I420 is also used on devices where texture sharing is unavailable.
- **Tencent FFI symbols are missing in an iOS release build.** Check the Runner target’s effective `STRIP_STYLE`. The plugin podspec sets it to `non-global` so the native symbols remain available.
