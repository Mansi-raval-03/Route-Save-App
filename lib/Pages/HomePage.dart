import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:routesaver_app/Pages/ChatPage.dart';
import 'package:routesaver_app/Pages/PRofilePage.dart';
import 'package:routesaver_app/Pages/RequestPage.dart';
import 'package:routesaver_app/main.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controllerCompleter = Completer();
  final Set<Marker> _markers = {};
  StreamSubscription<QuerySnapshot>? _providerSub;
  List<Map<String, dynamic>> nearbyProviders = [];
  XFile? _pickedImage;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    appState.startLocationUpdates();
    _listenProviders();
  }

  @override
  void dispose() {
    _providerSub?.cancel();
    super.dispose();
  }

  void _listenProviders() {
    // For demo purposes, we will listen to a collection 'service_providers'
    _providerSub = FirebaseFirestore.instance
        .collection('service_providers')
        .snapshots()
        .listen((snap) {
      nearbyProviders = snap.docs.map((d) => d.data()).cast<Map<String, dynamic>>().toList();
      setState(() {});
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.camera);
    if (img != null) {
      setState(() => _pickedImage = img);
    }
  }

  Future<void> _sendHelpRequest(String issue) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
      return;
    }
    if (appState.currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location unknown')));
      return;
    }

    final id = const Uuid().v4();
    final doc = FirebaseFirestore.instance.collection('help_requests').doc(id);
    await doc.set({
      'id': id,
      'user_id': user.uid,
      'issue': issue,
      'lat': appState.currentPosition!.latitude,
      'lng': appState.currentPosition!.longitude,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
      'photo': _pickedImage?.path, // TODO: upload to storage
    });

    // Optionally notify nearby providers via FCM (backend required)

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Help request sent')));
  }

  Future<void> _callProvider(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openChat(String providerId, String providerName) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatPage(providerId: providerId, providerName: providerName)));
  }

  Future<void> _shareReport(String requestId) async {
    final doc = await FirebaseFirestore.instance.collection('help_requests').doc(requestId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final report = StringBuffer();
    report.writeln('Incident Report - $requestId');
    report.writeln('User: ${data['user_id']}');
    report.writeln('Issue: ${data['issue']}');
    report.writeln('Location: ${data['lat']}, ${data['lng']}');
    report.writeln('Status: ${data['status']}');
    report.writeln('Time: ${data['created_at']}');

    await Share.share(report.toString());
  }

  Widget _buildMap(AppState appState) {
    final pos = appState.currentPosition;
    final initialCamera = CameraPosition(
      target: pos != null ? LatLng(pos.latitude, pos.longitude) : const LatLng(20.5937, 78.9629),
      zoom: 14,
    );
    _markers.clear();
    if (pos != null) {
      _markers.add(Marker(markerId: const MarkerId('me'), position: LatLng(pos.latitude, pos.longitude), infoWindow: const InfoWindow(title: 'You')));
    }

    // Add provider markers
    for (var p in nearbyProviders) {
      if (p['lat'] != null && p['lng'] != null) {
        final mid = MarkerId(p['id'] ?? p['phone'] ?? const Uuid().v4());
        _markers.add(Marker(markerId: mid, position: LatLng(p['lat'], p['lng']), infoWindow: InfoWindow(title: p['name'] ?? 'Provider')));
      }
    }

    return GoogleMap(
      initialCameraPosition: initialCamera,
      markers: _markers,
      myLocationEnabled: true,
      onMapCreated: (c) {
        _mapController = c;
        if (!_controllerCompleter.isCompleted) _controllerCompleter.complete(c);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guidance in Bad Time'),
        actions: [
          IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfilePage())), icon: const Icon(Icons.person))
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildMap(appState),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      FloatingActionButton.extended(
                        heroTag: 'share',
                        onPressed: () async {
                          // toggle live sharing with optional timer
                          final minutes = await showDialog<int?>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Share live location for how many minutes? (0 = until turned off)'),
                              content: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'minutes'), onSubmitted: (v) { Navigator.of(context).pop(int.tryParse(v)); }),
                              actions: [TextButton(onPressed: () => Navigator.of(context).pop(0), child: const Text('Off')), TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
                            ),
                          );
                          await appState.toggleLiveSharing(minutes: minutes == 0 ? null : minutes);
                        },
                        label: Text(appState.isSharingLive ? 'Stop Share' : 'Live Share'),
                        icon: const Icon(Icons.share),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.extended(
                        heroTag: 'center',
                        onPressed: () async {
                          if (appState.currentPosition != null && _mapController != null) {
                            final c = await _controllerCompleter.future;
                            await c.animateCamera(CameraUpdate.newLatLng(LatLng(appState.currentPosition!.latitude, appState.currentPosition!.longitude)));
                          }
                        },
                        label: const Text('Center'),
                        icon: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          onPressed: () async {
                            // quick help with default issue
                            await _pickImage();
                            await _sendHelpRequest('General breakdown');
                          },
                          icon: const Icon(Icons.help),
                          label: const Text('Help Me'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(onPressed: () => showModalBottomSheet(context: context, builder: (_) => _buildProvidersSheet()), icon: const Icon(Icons.car_repair)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text('Nearby providers: ${nearbyProviders.length}')),
                      TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) =>  RequestsPage())), child: const Text('Requests'))
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProvidersSheet() {
    if (nearbyProviders.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('No providers nearby')));
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: nearbyProviders.length,
      itemBuilder: (context, idx) {
        final p = nearbyProviders[idx];
        return ListTile(
          leading: const Icon(Icons.build),
          title: Text(p['name'] ?? 'Provider'),
          subtitle: Text(p['phone'] ?? ''),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(onPressed: () => _callProvider(p['phone'] ?? ''), icon: const Icon(Icons.call)),
            IconButton(onPressed: () => _openChat(p['id'] ?? 'unknown', p['name'] ?? 'Provider'), icon: const Icon(Icons.chat)),
          ]),
        );
      },
    );
  }
}
