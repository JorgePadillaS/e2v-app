import 'src/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';
import 'src/core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AppStartupWidget()));
}

class AppStartupWidget extends StatefulWidget {
  const AppStartupWidget({super.key});

  @override
  State<AppStartupWidget> createState() => _AppStartupWidgetState();
}

class _AppStartupWidgetState extends State<AppStartupWidget> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initApp();
  }

  Future<void> _initApp() async {

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await AppConfig.loadRemoteConfig();
    if (kDebugMode) {
      print(
        '*** Remote config loaded: apiBaseUrl=${AppConfig.apiBaseUrl}, wsHost=${AppConfig.wsHost}, reverbKey=${AppConfig.reverbKey}, disclaimerUrl=${AppConfig.disclaimerUrl} ***',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(body: Center(child: Text('Firebase Error: ${snapshot.error}', textDirection: TextDirection.ltr))),
          );
        }

        if (snapshot.connectionState == ConnectionState.done) {
          return const E2VApp();
        }

        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      },
    );
  }
}
