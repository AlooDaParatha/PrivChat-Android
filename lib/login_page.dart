import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isSignup = false;
  bool loading = false;
  String? error;

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _users = FirebaseFirestore.instance.collection('users');

  Future<String> _hashPassword(String pass) async {
    return sha256.convert(utf8.encode(pass)).toString();
  }

  Future<void> _handleAuth() async {
    setState(() {
      loading = true;
      error = null;
    });

    final username = _usernameCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text.trim();
    final displayName = _displayNameCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        error = "Please fill all fields.";
        loading = false;
      });
      return;
    }

    try {
      final hash = await _hashPassword(password);
      final doc = await _users.doc(username).get();

      if (isSignup) {
        if (doc.exists) {
          setState(() => error = "Username already taken.");
        } else {
          await _users.doc(username).set({
            'passwordHash': hash,
            'displayName': displayName.isNotEmpty ? displayName : username,
            'createdAt': FieldValue.serverTimestamp(),
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('priv_username', username);
          await prefs.setString(
              'priv_displayName', displayName.isNotEmpty ? displayName : username);

          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        }
      } else {
        if (!doc.exists) {
          setState(() => error = "No such user. Please sign up.");
        } else if (doc.data()!['passwordHash'] == hash) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('priv_username', username);
          await prefs.setString(
              'priv_displayName', doc.data()!['displayName'] ?? username);

          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        } else {
          setState(() => error = "Incorrect password.");
        }
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7C5CFF);
    const accent2 = Color(0xFF3DDC97);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0x10FFFFFF), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: Colors.white10),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 40)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [accent, accent2],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text("PC",
                            style: TextStyle(
                                color: Color(0xFF04101A),
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PrivChat',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Custom username/password',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(isSignup ? "Create Account" : "Sign In",
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'your-username (no spaces)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Password', hintText: '••••••••'),
                  ),
                  if (isSignup) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _displayNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        hintText: 'Name visible in chat',
                      ),
                    ),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13)),
                    ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF04101A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: loading ? null : _handleAuth,
                    child: Text(loading
                        ? "Please wait..."
                        : (isSignup ? "Create Account" : "Sign In")),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() => isSignup = !isSignup);
                    },
                    child: Text(isSignup
                        ? "Switch to Sign In"
                        : "Create new account"),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Passwords are hashed with SHA-256 before saving to Firestore. Demo use only — not production secure.",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  } //Sigma Web Development Html
}
