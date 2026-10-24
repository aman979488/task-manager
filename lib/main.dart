import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'routes/app_router.dart';
import 'services/notification_service.dart';
import 'viewmodels/auth_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  final notificationService = NotificationService();
  await notificationService.initialize();
  final authViewModel = AuthViewModel(notificationService: notificationService);
  runApp(
    ChangeNotifierProvider<AuthViewModel>.value(
      value: authViewModel,
      child: MyApp(router: AppRouter.create(authViewModel)),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFBE64E)),
      useMaterial3: true,
    );
    final textTheme = baseTheme.textTheme.copyWith(
      headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(fontSize: 24),
      titleLarge: baseTheme.textTheme.titleLarge?.copyWith(fontSize: 24),
      titleMedium: baseTheme.textTheme.titleMedium?.copyWith(fontSize: 16),
      titleSmall: baseTheme.textTheme.titleSmall?.copyWith(fontSize: 14),
      bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: baseTheme.textTheme.bodySmall?.copyWith(fontSize: 12),
      labelLarge: baseTheme.textTheme.labelLarge?.copyWith(fontSize: 16),
      labelMedium: baseTheme.textTheme.labelMedium?.copyWith(fontSize: 14),
      labelSmall: baseTheme.textTheme.labelSmall?.copyWith(fontSize: 12),
    );

    return MaterialApp.router(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(textTheme: textTheme),
      routerConfig: router,
    );
  }
}
