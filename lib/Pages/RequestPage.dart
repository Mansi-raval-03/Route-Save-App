import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('help_requests').orderBy('created_at', descending: true);
    return Scaffold(
      appBar: AppBar(title: const Text('Help Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: col.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, idx) {
              final d = docs[idx];
              final data = d.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['issue'] ?? 'Issue'),
                subtitle: Text('Status: ${data['status'] ?? ''}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'accept') {
                      await d.reference.update({'status': 'accepted', 'provider_id': FirebaseAuth.instance.currentUser!.uid});
                    } else if (v == 'complete') {
                      await d.reference.update({'status': 'completed'});
                    } else if (v == 'report') {
                      await Share.share('Report for request ${data['id']}');
                    }
                  },
                  itemBuilder: (_) => [const PopupMenuItem(value: 'accept', child: Text('Accept')), const PopupMenuItem(value: 'complete', child: Text('Mark Completed')), const PopupMenuItem(value: 'report', child: Text('Share Report'))],
                ),
              );
            },
          );
        },
      ),
    );
  }
}