import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  final String providerId;
  final String providerName;
  const ChatPage({super.key, required this.providerId, required this.providerName});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _ctrl = TextEditingController();
  final _messagesCol = FirebaseFirestore.instance.collection('messages');

  void _sendMessage() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser!;
    await _messagesCol.add({
      'from': user.uid,
      'to': widget.providerId,
      'text': text,
      'created_at': FieldValue.serverTimestamp(),
    });
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(title: Text('Chat with ${widget.providerName}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesCol.where('to', whereIn: [user.uid, widget.providerId]).orderBy('created_at', descending: false).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, idx) {
                    final d = docs[idx];
                    final data = d.data() as Map<String, dynamic>;
                    final mine = data['from'] == user.uid;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: mine ? Colors.blue.shade200 : Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                        child: Text(data['text'] ?? ''),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _ctrl, decoration: const InputDecoration(hintText: 'Message'))),
                IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send))
              ],
            ),
          )
        ],
      ),
    );
  }
}


