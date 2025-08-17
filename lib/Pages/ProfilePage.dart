import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _emContactCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final d = doc.data()!;
      _nameCtrl.text = d['name'] ?? '';
      _vehicleCtrl.text = d['vehicle'] ?? '';
      _emContactCtrl.text = d['emergency_contact'] ?? '';
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': _nameCtrl.text.trim(),
      'vehicle': _vehicleCtrl.text.trim(),
      'emergency_contact': _emContactCtrl.text.trim(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextFormField(controller: _vehicleCtrl, decoration: const InputDecoration(labelText: 'Vehicle')),
            TextFormField(controller: _emContactCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact (phone)')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loading ? null : _saveProfile, child: _loading ? const CircularProgressIndicator() : const Text('Save Profile')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () async { await FirebaseAuth.instance.signOut(); }, child: const Text('Sign Out'))
          ],
        ),
      ),
    );
  }
}
