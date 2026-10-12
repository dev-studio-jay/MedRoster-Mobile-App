import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'state/hospital_store.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/join_screen.dart';
import 'screens/hospital_shell.dart';
import 'screens/ward_home_screen.dart';
import 'screens/wards_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/import_roster_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MedRosterApp());
}

final _router = GoRouter(
  refreshListenable: AuthService.instance.authListenable,
  redirect: (context, state) {
    final loggedIn = AuthService.instance.currentUser != null;
    final loc = state.matchedLocation;
    final onAuth = loc.startsWith('/auth');
    final onJoin = loc == '/auth/join';

    if (!loggedIn && !onAuth) {
      ApiService.instance.clearProfile();
      HospitalStore.instance.hospital = null;
      HospitalStore.instance.error = null;
      HospitalStore.instance.loading = false;
      return '/auth/login';
    }
    // Allow join while logged out; bounce other auth routes when signed in
    if (loggedIn && onAuth && !onJoin) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/auth/join', builder: (_, __) => const JoinScreen()),
    GoRoute(
      path: '/schedule/:schedId',
      builder: (_, state) => ScheduleScreen(scheduleId: state.pathParameters['schedId']!),
    ),
    GoRoute(
      path: '/import/:wardId',
      builder: (_, state) => ImportRosterScreen(wardId: state.pathParameters['wardId']!),
    ),
    ShellRoute(
      builder: (context, state, child) => HospitalShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Center(child: CircularProgressIndicator())),
        GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
        GoRoute(path: '/wards', builder: (_, __) => const WardsScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(
          path: '/ward/:wardId',
          builder: (_, state) => WardHomeScreen(wardId: state.pathParameters['wardId']!),
        ),
      ],
    ),
  ],
);

class MedRosterApp extends StatelessWidget {
  const MedRosterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MedRoster',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
