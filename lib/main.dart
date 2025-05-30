import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/login_screen.dart';
import 'screens/first_time_sign_in_screen.dart';
import 'screens/arcade_screen.dart';
import 'screens/canteen_screen.dart';
import 'screens/payment_success_screen.dart';
import 'screens/under_construction_screen.dart';
import 'screens/ritz_purchase_screen.dart';
import 'screens/event_registration_screen.dart';
import 'screens/leave_od_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/purchase_history_screen.dart';
import 'screens/bus_tracking_screen.dart'; // Added
import 'user_provider.dart';
import 'providers/campus_status_provider.dart';
import 'services/location_service.dart'; // Added
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Clear cached user data if no authenticated user
  final prefs = await SharedPreferences.getInstance();
  if (fb_auth.FirebaseAuth.instance.currentUser == null) {
    await prefs.remove('user_data');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => CampusStatusProvider()),
        ChangeNotifierProvider(create: (context) => LocationService()), // Added
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start checking location status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CampusStatusProvider>(context, listen: false)
          .checkLocationAndUpdateStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      fb_auth.FirebaseAuth.instance.signOut();
      SharedPreferences.getInstance()
          .then((prefs) => prefs.remove('user_data'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<fb_auth.User?>(
      stream: fb_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final firebaseUser = snapshot.data;
        final bool isLoggedIn = firebaseUser != null;

        if (isLoggedIn) {
          // Fetch user data asynchronously
          FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser!.uid)
              .get()
              .then((doc) {
            if (doc.exists && context.mounted) {
              final userData = {
                'email': firebaseUser.email ?? '',
                'name': doc['name'] ?? 'User',
                'department': doc['department'] ?? '',
                'class': doc['class'] ?? '',
                'year': doc['year'] ?? '',
                'regdNumber': doc['regdNumber'] ?? '',
              };
              Provider.of<UserProvider>(context, listen: false)
                  .setUserFromJson(userData);
            }
          }).catchError((e) {
            print('Error fetching user data: $e');
          });
        } else {
          // Clear UserProvider if not logged in
          Provider.of<UserProvider>(context, listen: false).clearUser();
        }

        return MaterialApp(
          title: 'RITian App',
          navigatorKey: navigatorKey,
          theme: ThemeData(primarySwatch: Colors.blue),
          initialRoute: isLoggedIn ? '/home' : '/login',
          navigatorObservers: [AuthNavigatorObserver()],
          onGenerateRoute: (settings) {
            final routes = {
              '/login': (context) => const LoginScreen(),
              '/first_time_sign_in': (context) => const FirstTimeSignInScreen(),
              '/home': (context) => const HomeScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/arcade': (context) => const ArcadeScreen(),
              '/canteen': (context) => const CanteenScreen(),
              '/payment': (context) => PaymentScreen(
                    file: null,
                    copies: 1,
                    isColor: false,
                    printSide: 'Single Sided',
                    customInstructions: '',
                    stationeryCart: {},
                    stationeryItems: [],
                    foodCart: {},
                    foodItems: [],
                    isTakeaway: false,
                  ),
              '/payment-success': (context) => const PaymentSuccessScreen(),
              '/under-construction': (context) =>
                  const UnderConstructionScreen(),
              '/buy_ritz': (context) => const RitzPurchaseScreen(),
              '/event_registration': (context) =>
                  const EventRegistrationScreen(),
              '/leaveandod': (context) => const LeaveOdScreen(),
              '/assignment_submission': (context) =>
                  const UnderConstructionScreen(),
              '/gpa_book': (context) => const UnderConstructionScreen(),
              '/class_committee': (context) => const UnderConstructionScreen(),
              '/raise_query': (context) => const UnderConstructionScreen(),
              '/apply_certificates': (context) =>
                  const UnderConstructionScreen(),
              '/timetable': (context) => const TimetableScreen(),
              '/exam_results': (context) => const UnderConstructionScreen(),
              '/fee_details': (context) => const UnderConstructionScreen(),
              '/purchase_history': (context) => const PurchaseHistoryScreen(),
              '/bus_tracking': (context) => const BusTrackingScreen(), // Added
            };

            final WidgetBuilder? builder = routes[settings.name];
            if (builder != null) {
              return MaterialPageRoute(
                builder: builder,
                settings: settings,
              );
            }
            return MaterialPageRoute(builder: (context) => const LoginScreen());
          },
          builder: (context, child) {
            return WillPopScope(
              onWillPop: () async {
                if (fb_auth.FirebaseAuth.instance.currentUser == null) {
                  return false; // Prevent back navigation
                }
                return true;
              },
              child: child ?? const LoginScreen(),
            );
          },
        );
      },
    );
  }
}

class AuthNavigatorObserver extends NavigatorObserver {
  bool _isRedirecting = false;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _checkAuth(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _checkAuth(newRoute);
    }
  }

  void _checkAuth(Route<dynamic> route) {
    if (_isRedirecting) return;
    final String? routeName = route.settings.name;
    final bool isAuthRoute =
        routeName == '/login' || routeName == '/first_time_sign_in';
    if (!isAuthRoute && fb_auth.FirebaseAuth.instance.currentUser == null) {
      _isRedirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil(
              '/login',
              (Route<dynamic> route) => false,
            )
            .then((_) => _isRedirecting = false);
      });
    }
  }
}
