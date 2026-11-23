import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_credentials.dart';
import 'nosmai_dashboard.dart';
import 'viewer_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const TencentLiveApp());
}

class TencentLiveApp extends StatelessWidget {
  const TencentLiveApp({
    super.key,
    this.credentials = const AppCredentials.fromEnvironment(),
  });

  final AppCredentials credentials;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nosmai × Tencent Live',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF54D6E7),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0E1420),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      home: NosmaiDashboardPage(
        hostCredentials: credentials,
        viewerCredentials: credentials,
        buildViewerPage: (roomId) => ViewerPage(credentials: credentials, roomId: roomId),
      ),
    );
  }
}
