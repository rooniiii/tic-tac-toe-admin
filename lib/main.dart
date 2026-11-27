import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'screen/admin_login_screen.dart';
import 'screen/dashboard_screen.dart';
import 'screen/userscreen.dart';
import 'screen/profiles_screen.dart';
import 'screen/statistics_screen.dart';
import 'screen/game_history_screen.dart';
import 'screen/manage_admins_screen.dart';
import 'screen/activity_log_screen.dart';
import 'screen/ads_screen.dart';
import 'widgets/admin_drawer.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const NeonXOAdminApp());
}

class NeonXOAdminApp extends StatelessWidget {
  /// First screen. Defaults to the admin login gate; tests pass a screen
  /// that does not need Firebase.
  final Widget home;

  const NeonXOAdminApp({super.key, this.home = const AdminAppRoot()});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEON XO Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: home,
    );
  }
}

class AdminAppRoot extends StatefulWidget {
  const AdminAppRoot({super.key});

  @override
  State<AdminAppRoot> createState() => _AdminAppRootState();
}

class _AdminAppRootState extends State<AdminAppRoot> {
  late final Stream<bool> _adminSessionStream;

  @override
  void initState() {
    super.initState();

    _adminSessionStream =
        FirebaseAuth.instance.authStateChanges().asyncMap((user) async {
          if (user == null) {
            return false;
          }

          try {
            final adminDoc = await FirebaseFirestore.instance
                .collection('admins')
                .doc(user.uid)
                .get();

            final isAdmin =
                adminDoc.exists && adminDoc.data()?['role'] == 'admin';

            if (!isAdmin) {
              await FirebaseAuth.instance.signOut();
              return false;
            }

            return true;
          } catch (e) {
            debugPrint('Admin session verification error: $e');
            return false;
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _adminSessionStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.neonCyan,
              ),
            ),
          );
        }

        if (snapshot.data == true) {
          return AdminNavigationShell(
            onLogout: () async {
              await FirebaseAuth.instance.signOut();
            },
          );
        }

        return AdminLoginScreen(
          onLoginSuccess: () {},
        );
      },
    );
  }
}

class AdminNavigationShell extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminNavigationShell({
    super.key,
    required this.onLogout,
  });

  @override
  State<AdminNavigationShell> createState() =>
      _AdminNavigationShellState();
}

class _AdminNavigationShellState extends State<AdminNavigationShell>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  /// Admin sessions end automatically after this much inactivity, so an
  /// unattended phone does not stay logged in to the admin panel.
  static const Duration _idleTimeout = Duration(minutes: 15);

  Timer? _idleTimer;
  DateTime _lastActivity = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Global hooks: also catch activity inside dialogs and menus, which are
    // drawn above this widget.
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
    _resetIdleTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _idleTimer?.cancel();
    super.dispose();
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent || event is PointerSignalEvent) {
      _resetIdleTimer();
    }
  }

  bool _onKey(KeyEvent event) {
    _resetIdleTimer();
    return false; // never consume the key
  }

  void _resetIdleTimer() {
    _lastActivity = DateTime.now();
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _onIdleTimeout);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Timers do not run reliably in the background: check on resume.
    if (state == AppLifecycleState.resumed &&
        DateTime.now().difference(_lastActivity) >= _idleTimeout) {
      _onIdleTimeout();
    }
  }

  void _onIdleTimeout() {
    if (!mounted) return;
    _idleTimer?.cancel();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Signed out after 15 minutes of inactivity.'),
      ),
    );
    widget.onLogout();
  }

  static const List<String> _titles = [
    'Dashboard Overview',
    'Registered Users',
    'Player Profiles',
    'Statistics',
    'Game History',
    'Manage Admins',
    'Activity Log',
    'Advertisements',
  ];

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(onLogout: widget.onLogout);
      case 1:
        return const UsersScreen();
      case 2:
        return const ProfilesScreen();
      case 3:
        return const StatisticsScreen();
      case 4:
        return const GameHistoryScreen();
      case 5:
        return const ManageAdminsScreen();
      case 6:
        return const ActivityLogScreen();
      case 7:
        return const AdsScreen();
      default:
        return DashboardScreen(onLogout: widget.onLogout);
    }
  }

  void _selectScreen(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Row(
              children: [
                AdminDrawer(
                  selectedIndex: _selectedIndex,
                  onItemSelected: _selectScreen,
                  onLogout: widget.onLogout,
                  isSidebar: true,
                ),
                Expanded(
                  child: _getSelectedScreen(),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: Text(
              _titles[_selectedIndex],
              style: const TextStyle(
                color: AppTheme.neonCyan,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            backgroundColor: AppTheme.surface,
            iconTheme: const IconThemeData(
              color: AppTheme.neonCyan,
            ),
          ),
          drawer: AdminDrawer(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              Navigator.pop(context);
              _selectScreen(index);
            },
            onLogout: widget.onLogout,
          ),
          body: _getSelectedScreen(),
        );
      },
    );
  }
}