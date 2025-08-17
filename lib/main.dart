import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:routesaver_app/Pages/AuthPage.dart';
import 'package:routesaver_app/Pages/HomePage.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      
      );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppState())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Route Save',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3AB792)),
          useMaterial3: true,
        ),
        home: const RootPage(),
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  User? user = FirebaseAuth.instance.currentUser;
  Position? currentPosition;
  StreamSubscription<Position>? _positionSub;
  bool isSharingLive = false;
  Timer? _sharingTimer;

  AppState() {
    // Listen to Firebase auth state
    FirebaseAuth.instance.authStateChanges().listen((u) {
      user = u;
      notifyListeners();
    });
  }

  Future<void> startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // handle service disabled
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    _positionSub ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      currentPosition = pos;
      notifyListeners();
      if (isSharingLive) {
        _updateLiveLocationToFirestore(pos);
      }
    });
  }

  Future<void> stopLocationUpdates() async {
    await _positionSub?.cancel();
    _positionSub = null;
  }

  Future<void> toggleLiveSharing({int? minutes}) async {
    isSharingLive = !isSharingLive;
    notifyListeners();
    if (isSharingLive) {
      // immediate first update
      if (currentPosition != null) {
        await _updateLiveLocationToFirestore(currentPosition!);
      }
      if (minutes != null && minutes > 0) {
        _sharingTimer?.cancel();
        _sharingTimer = Timer(Duration(minutes: minutes), () async {
          isSharingLive = false;
          notifyListeners();
          // Optionally remove live location from firestore or mark as stopped
          await FirebaseFirestore.instance
              .collection('live_shares')
              .doc(user!.uid)
              .delete();
        });
      }
    } else {
      _sharingTimer?.cancel();
      // stop sharing: remove doc
      await FirebaseFirestore.instance
          .collection('live_shares')
          .doc(user!.uid)
          .delete();
    }
  }

  Future<void> _updateLiveLocationToFirestore(Position pos) async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('live_shares')
        .doc(user!.uid)
        .set({
      'user_id': user!.uid,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}

class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) {
          return const AuthPage();
        }
        return const HomePage();
      },
    );
  }
}