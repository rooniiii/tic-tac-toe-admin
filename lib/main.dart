import 'package:flutter/material.dart';
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
  const NeonXOAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEON XO Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AdminAppRoot(),
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
            backgroundColor: Color(0xFF0B0B2B),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00E5FF),
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

class _AdminNavigationShellState extends State<AdminNavigationShell> {
  int _selectedIndex = 0;

  static const List<String> _titles = [
    'Dashboard Overview',
    'Registered Users',
    'Player Profiles',
    'Statistics',
    'Game History',
    'Manage Admins',
  ];

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(onLogout: widget.onLogout);
      case 1:
        return UsersScreen();
      case 2:
        return ProfilesScreen();
      case 3:
        return StatisticsScreen();
      case 4:
        return GameHistoryScreen();
      case 5:
        return ManageAdminsScreen();
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
            backgroundColor: const Color(0xFF0B0B2B),
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
          backgroundColor: const Color(0xFF0B0B2B),
          appBar: AppBar(
            title: Text(
              _titles[_selectedIndex],
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            backgroundColor: const Color(0xFF171F35),
            iconTheme: const IconThemeData(
              color: Color(0xFF00E5FF),
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