import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _loading = false;

  Future<void> signInWithEmail() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(), password: _passCtrl.text);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // create user
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailCtrl.text.trim(), password: _passCtrl.text);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loading ? null : signInWithEmail, child: _loading ? const CircularProgressIndicator() : const Text('Sign in / Register')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () async {
              // TODO: implement Google sign in
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Sign-In not implemented in this starter code')));
            }, child: const Text('Sign in with Google')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () async {
              // TODO: implement phone sign-in flow
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone Sign-In not implemented in this starter code')));
            }, child: const Text('Sign in with Phone')),
          ],
        ),
      ),
    );
  }
}