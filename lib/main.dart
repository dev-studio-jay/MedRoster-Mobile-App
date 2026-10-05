import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/departments_screen.dart';
import 'screens/staff_screen.dart';
import 'screens/schedules_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MedRosterApp());
}

final _router = GoRouter(
  refreshListenable: AuthService.instance.authListenable,
  redirect: (context, state) {
    final loggedIn = AuthService.instance.currentUser != null;
    final onAuth = state.matchedLocation.startsWith('/auth');
    if (!loggedIn && !onAuth) {
      ApiService.instance.clearProfile();
      return '/auth/login';
    }
    if (loggedIn && onAuth) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/departments', builder: (_, __) => const DepartmentsScreen()),
        GoRoute(path: '/staff', builder: (_, __) => const StaffScreen()),
        GoRoute(path: '/schedules', builder: (_, __) => const SchedulesScreen()),
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
      theme: _buildTheme(),
      routerConfig: _router,
    );
  }

  ThemeData _buildTheme() {
    const ghsGreen = Color(0xFF006B3F);
    const ghsGold = Color(0xFFFCD116);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ghsGreen,
        primary: ghsGreen,
        secondary: ghsGold,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ghsGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      navigationDrawerTheme: const NavigationDrawerThemeData(
        indicatorColor: Color(0xFFE8F5EE),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ghsGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexFor(location),
        onDestinationSelected: (i) => _navigate(context, i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.account_tree_outlined), selectedIcon: Icon(Icons.account_tree), label: 'Departments'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Staff'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Schedules'),
        ],
      ),
    );
  }

  int _indexFor(String location) {
    if (location.startsWith('/departments')) return 1;
    if (location.startsWith('/staff')) return 2;
    if (location.startsWith('/schedules')) return 3;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    const paths = ['/', '/departments', '/staff', '/schedules'];
    context.go(paths[index]);
  }
}
