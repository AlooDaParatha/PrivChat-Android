import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends StatefulWidget {
  final String groupId;
  const ChatPage({super.key, required this.groupId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final db = FirebaseFirestore.instance;
  final _msgCtrl = TextEditingController();

  String? username;
  String? displayName;
  String groupName = '';
  bool loading = true;
  bool sending = false;

  Map<String, dynamic> members = {};
  String? replyingToId;
  Map<String, dynamic>? replyingToMsg;

  Stream<QuerySnapshot>? msgStream;
  Stream<QuerySnapshot>? typingStream;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('priv_username');
    displayName = prefs.getString('priv_displayName') ?? username;
    if (username == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
      return;
    }

    final snap = await db.collection('groups').doc(widget.groupId).get();
    if (!snap.exists) {
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
      return;
    }

    groupName = snap.data()?['name'] ?? widget.groupId;
    _listenMessages();
    _listenTyping();

    setState(() => loading = false);
  }

  void _listenMessages() {
    msgStream = db
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .orderBy('ts', descending: false)
        .snapshots();
  }

  void _listenTyping() {
    typingStream = db
        .collection('groups')
        .doc(widget.groupId)
        .collection('typing')
        .snapshots();
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || sending) return;

    setState(() => sending = true);

    final msg = {
      'sender': username,
      'displayName': displayName,
      'text': text,
      'ts': FieldValue.serverTimestamp(),
    };

    if (replyingToMsg != null) {
      msg['replyTo'] = {
        'id': replyingToId,
        'sender': replyingToMsg!['sender'],
        'displayName': replyingToMsg!['displayName'],
        'text': replyingToMsg!['text'],
      };
    }

    await db
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .add(msg);

    _msgCtrl.clear();
    setState(() {
      sending = false;
      replyingToId = null;
      replyingToMsg = null;
    });
  }

  Future<void> _deleteMessage(String id) async {
    await db
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .doc(id)
        .delete();
  }

  void _setReply(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      replyingToId = doc.id;
      replyingToMsg = data;
    });
  }

  void _cancelReply() {
    setState(() {
      replyingToId = null;
      replyingToMsg = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7C5CFF);
    const accent2 = Color(0xFF3DDC97);

    return Scaffold(
      backgroundColor: const Color(0xFF030518),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071023),
        title: Text(groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: msgStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final docs = snapshot.data!.docs;
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final isMe = data['sender'] == username;
                          final ts = (data['ts'] as Timestamp?)?.toDate();
                          final reply = data['replyTo'] as Map<String, dynamic>?;

                          return Align(
                            alignment:
                                isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: const Color(0xFF0F1C3A),
                                  shape: const RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.vertical(top: Radius.circular(12))),
                                  builder: (_) {
                                    return SafeArea(
                                      child: Wrap(
                                        children: [
                                          ListTile(
                                            leading: const Icon(Icons.reply,
                                                color: Colors.white70),
                                            title: const Text("Reply",
                                                style: TextStyle(color: Colors.white)),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _setReply(doc);
                                            },
                                          ),
                                          if (isMe)
                                            ListTile(
                                              leading: const Icon(Icons.delete,
                                                  color: Colors.redAccent),
                                              title: const Text("Delete",
                                                  style: TextStyle(color: Colors.redAccent)),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _deleteMessage(doc.id);
                                              },
                                            ),
                                          ListTile(
                                            title: const Text("Cancel",
                                                textAlign: TextAlign.center,
                                                style: TextStyle(color: Colors.white70)),
                                            onTap: () => Navigator.pop(context),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                constraints: const BoxConstraints(maxWidth: 280),
                                decoration: BoxDecoration(
                                  gradient: isMe
                                      ? const LinearGradient(
                                          colors: [Color(0xFF7C5CFF), Color(0xFF3DDC97)],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        )
                                      : null,
                                  color: isMe ? null : const Color(0xFF0E1A32),
                                  borderRadius: BorderRadius.circular(20),
                                  border: isMe ? null : Border.all(color: Colors.white10),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (reply != null)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 4),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border(
                                            left: BorderSide(
                                                color: accent.withValues(alpha: 0.8), width: 3),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(reply['displayName'] ?? '',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12)),
                                            Text(reply['text'] ?? '',
                                                style: const TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    Text(
                                      data['text'] ?? '',
                                      style: TextStyle(
                                        color: isMe
                                            ? const Color(0xFF04101A)
                                            : Colors.white,
                                        fontWeight:
                                            isMe ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${data['displayName']} • ${ts != null ? "${ts.hour}:${ts.minute.toString().padLeft(2, '0')}" : ''}",
                                      style: TextStyle(
                                          color: isMe
                                              ? const Color(0xFF04101A).withValues(alpha: 0.7)
                                              : Colors.white54,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                if (replyingToMsg != null)
                  Container(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      border: Border(
                        left: BorderSide(color: accent, width: 3),
                      ),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Replying to ${replyingToMsg!['displayName']}",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                              Text(replyingToMsg!['text'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: _cancelReply,
                        )
                      ],
                    ),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Message…",
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: accent2),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
