import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosmai_tencent_live/nosmai_tencent_live.dart';
import 'package:nosmai_tencent_live/src/rtc_session.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const credentials = NosmaiLiveCredentials(
    sdkAppId: 1400000000,
    userId: 'host_001',
    userSig: 'not-a-real-token',
  );
  late FakeCloud cloud;
  late FakeBridge bridge;

  setUp(() {
    callLog.clear();
    RtcSession.resetRestartGuardForTesting();
    cloud = FakeCloud();
    bridge = FakeBridge();
  });

  NosmaiLiveBroadcaster create({bool nosmaiReady = true, bool audio = true, bool cleanup = true}) {
    final live = NosmaiLiveBroadcaster(
      credentials: credentials,
      room: const NosmaiLiveRoom(1001),
      video: NosmaiLiveVideoConfig.hd,
      publishAudio: audio,
      cloudFactory: () async => cloud,
      bridge: bridge,
      statsInterval: const Duration(milliseconds: 10),
      nosmaiReady: () => nosmaiReady,
    );
    if (cleanup) {
      addTearDown(() async {
        await live.stop();
        live.dispose();
      });
    }
    return live;
  }

  /// Starts [live] and confirms room entry once Tencent was asked to enter.
  Future<void> startAndJoin(NosmaiLiveBroadcaster live, {int result = 10}) async {
    final started = live.start();
    await pumpEventQueue();
    cloud.events.onEnterRoom?.call(result);
    await started;
  }

  test('arms custom capture before entering, publishes only after joining', () async {
    final live = create();
    final started = live.start();
    await pumpEventQueue();
    expect(callLog, ['arm', 'enterRoom']);
    expect(bridge.publishing, isFalse);
    expect(live.state, NosmaiLiveState.connecting);
    cloud.events.onEnterRoom?.call(10);
    await started;
    expect(callLog, ['arm', 'enterRoom', 'publish']);
    expect(bridge.armedFps, 30);
    expect(live.state, NosmaiLiveState.live);
    expect(cloud.localAudioStarts, 1);
  });

  test('room entry alone does not report or complete a live video start', () async {
    bridge.sent = 0;
    final live = create();
    var completed = false;
    final started = live.start().then((_) => completed = true);
    await pumpEventQueue();
    cloud.events.onEnterRoom!(10);
    await pumpEventQueue();
    expect(live.isLive, isFalse);
    expect(completed, isFalse);
    bridge.sent = 1;
    await started;
    expect(live.isLive, isTrue);
  });

  test('idle, invalid and competing broadcasters cannot stop the live host', () async {
    final active = create();
    await startAndJoin(active);
    create(cleanup: false).dispose();
    await expectLater(create(nosmaiReady: false).start(), throwsA(isA<NosmaiLiveException>()));
    await expectLater(create().start(), throwsA(isA<NosmaiLiveException>()));
    expect(bridge.stops, 0);
    expect(bridge.publishing, isTrue);
    await active.stop();
    await startAndJoin(create());
    expect(bridge.stops, 1);
  });

  test('resuming needs new frames from the same publisher', () async {
    final live = create();
    await startAndJoin(live);
    live.didChangeAppLifecycleState(AppLifecycleState.hidden);
    expect(live.state, NosmaiLiveState.paused);
    live.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(bridge.resumes, 1);
    expect(live.isLive, isFalse);
    bridge.sent++;
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(live.isLive, isTrue);
  });

  test('stop halts frames before leaving the room and is idempotent', () async {
    final live = create();
    await startAndJoin(live);
    callLog.clear();
    await Future.wait([live.stop(), live.stop()]);
    expect(callLog, ['bridge.stop', 'exitRoom']);
    expect(bridge.stops, 1);
    expect(live.state, NosmaiLiveState.stopped);
  });

  test('a stop listener and a pending first frame release capture just once', () async {
    bridge.sent = 0;
    final live = create();
    live.addListener(() {
      if (live.state == NosmaiLiveState.stopping) live.stop();
    });
    final started = expectLater(live.start(), throwsA(isA<NosmaiLiveException>()));
    await pumpEventQueue();
    cloud.events.onEnterRoom!(10);
    await pumpEventQueue();
    await live.stop();
    await started;
    expect(bridge.stops, 1);
    expect(cloud.exits, 1);
    expect(live.state, NosmaiLiveState.stopped);
  });

  test('native frame counters reach stats', () async {
    final live = create();
    await startAndJoin(live);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(live.stats.framesFromNosmai, 60);
    expect(live.stats.framesSent, 48);
    expect(live.stats.transport, 'texture');
  });

  test('a rejected room entry fails, cleans up and throws', () async {
    final live = create();
    final started = live.start();
    await pumpEventQueue();
    cloud.events.onEnterRoom?.call(-3301);
    await expectLater(started, throwsA(isA<NosmaiLiveException>()));
    expect(live.state, NosmaiLiveState.failed);
    expect(live.error, contains('UserSig'));
    expect(bridge.publishing, isFalse);
    expect(bridge.stops, 1);
  });

  test('requires Nosmai to be initialized', () async {
    final live = create(nosmaiReady: false);
    await expectLater(live.start(),
        throwsA(isA<NosmaiLiveException>().having((e) => e.code, 'code', 'not_initialized')));
    expect(callLog, isNot(contains('arm')));
    expect(live.state, NosmaiLiveState.failed);
  });

  test('a denied microphone stops before arming', () async {
    bridge.microphoneGranted = false;
    final live = create();
    await expectLater(live.start(),
        throwsA(isA<NosmaiLiveException>().having((e) => e.code, 'code', 'permission_denied')));
    expect(callLog, isNot(contains('arm')));
    expect(callLog, isNot(contains('enterRoom')));
  });

  test('video-only broadcasts skip the microphone', () async {
    bridge.microphoneGranted = false;
    final live = create(audio: false);
    await startAndJoin(live);
    expect(live.state, NosmaiLiveState.live);
    expect(cloud.localAudioStarts, 0);
  });

  test('stopping while connecting never publishes', () async {
    final live = create();
    final started = live.start();
    await pumpEventQueue();
    await live.stop();
    cloud.events.onEnterRoom?.call(10);
    await expectLater(started, throwsA(isA<NosmaiLiveException>()));
    expect(callLog, isNot(contains('publish')));
    expect(live.state, NosmaiLiveState.stopped);
  });

  test('a session ended by Tencent fails the broadcast', () async {
    final live = create();
    await startAndJoin(live);
    cloud.events.onExitRoom?.call(2);
    await pumpEventQueue();
    expect(live.state, NosmaiLiveState.failed);
    expect(bridge.stops, 1);
  });

  test('mic and video mutes reach Tencent', () async {
    final live = create();
    await startAndJoin(live);
    live.setMicMuted(true);
    expect(cloud.localAudioStops, 1);
    live.setVideoMuted(true);
    expect(cloud.videoMuted, isTrue);
  });

  test('can only be started once', () async {
    final live = create();
    await startAndJoin(live);
    expect(live.start, throwsStateError);
  });
}
