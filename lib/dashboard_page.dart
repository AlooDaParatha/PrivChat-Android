import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? username;
  String? displayName;
  final _groupNameCtrl = TextEditingController();
  final _groupKeyCtrl = TextEditingController();
  final _joinIdCtrl = TextEditingController();

  final db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> myGroups = [];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('priv_username');
    displayName = prefs.getString('priv_displayName') ?? username;

    if (username == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
      return;
    }

    setState(() {});
    _loadGroups();
  }

  String _genId([int len = 5]) {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    return List.generate(len,
            (i) => chars[(chars.length * (DateTime.now().microsecond + i) / 999999)
                .floor() %
            chars.length])
        .join();
  }

  Future<void> _createGroup() async {
    final name = _groupNameCtrl.text.trim();
    final key = _groupKeyCtrl.text.trim();
    if (name.isEmpty) {
      _showMsg("Please enter a group name.");
      return;
    }

    String id = _genId();
    for (int i = 0; i < 6; i++) {
      final d = await db.collection('groups').doc(id).get();
      if (!d.exists) break;
      id = _genId();
    }

    await db.collection('groups').doc(id).set({
      'name': name,
      'key': key.isEmpty ? null : key,
      'owner': username,
      'members': [username],
      'createdAt': FieldValue.serverTimestamp(),
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('priv_group', id);

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/chat', arguments: {'groupId': id});
    }
  }

  Future<void> _joinGroup() async {
    final id = _joinIdCtrl.text.trim().toUpperCase();
    if (id.length != 5) {
      _showMsg("Invalid group ID.");
      return;
    }

    final ref = db.collection('groups').doc(id);
    final snap = await ref.get();

    if (!snap.exists) {
      _showMsg("Group not found.");
      return;
    }

    final data = snap.data()!;
    if (data['key'] != null && data['key'] != '') {
      final key = await _askForKey();
      if (key == null || key != data['key']) {
        _showMsg("Incorrect key.");
        return;
      }
    }

    await ref.update({
      'members': FieldValue.arrayUnion([username]),
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('priv_group', id);

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/chat', arguments: {'groupId': id});
    }
  }

  Future<void> _loadGroups() async {
    if (username == null) return;
    final q = await db
        .collection('groups')
        .where('members', arrayContains: username)
        .orderBy('createdAt', descending: true)
        .get();

    setState(() {
      myGroups = q.docs
          .map((d) => {
                'id': d.id,
                'name': d['name'] ?? 'Unnamed',
                'owner': d['owner'] ?? '',
              })
          .toList();
    });
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.black87,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<String?> _askForKey() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Group key required"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: "Enter group key"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text("OK")),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7C5CFF);
    const accent2 = Color(0xFF3DDC97);

    return Scaffold(
      backgroundColor: const Color(0xFF071023),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1520),
        title: const Text('PrivChat Dashboard'),
        actions: [
          if (displayName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text(
                  "$displayName ($username)",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ),
          TextButton(
            onPressed: _signOut,
            child: const Text("Sign out", style: TextStyle(color: Colors.white70)),
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0x10FFFFFF), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Create group",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _groupNameCtrl,
                    decoration: const InputDecoration(labelText: "Group name"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _groupKeyCtrl,
                    decoration:
                        const InputDecoration(labelText: "Group key (optional)"),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF04101A),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: _createGroup,
                    child: const Text("Create"),
                  ),
                  const Divider(height: 32, color: Colors.white10),
                  TextField(
                    controller: _joinIdCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration:
                        const InputDecoration(labelText: "Join group by ID (e.g. X5A9B)"),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: accent,
                      side: const BorderSide(color: Colors.white24),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: _joinGroup,
                    child: const Text("Join"),
                  ),
                  const SizedBox(height: 30),
                  const Text("Your groups",
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 10),
                  if (myGroups.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("No groups yet.",
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    Column(
                      children: myGroups
                          .map(
                            (g) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0x10FFFFFF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(g['name'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text("ID: ${g['id']}",
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13)),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setString(
                                          'priv_group', g['id']);
                                      if (context.mounted) {
                                        Navigator.pushReplacementNamed(
                                            context, '/chat',
                                            arguments: {'groupId': g['id']});
                                      }
                                    },
                                    child: const Text("Open"),
                                  )
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
