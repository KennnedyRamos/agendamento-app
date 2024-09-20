import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPage();
}

class _PhoneAuthPage extends State<PhoneAuthPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsController = TextEditingController();
  String _verificationId = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Auth Example')),
      body: Column(
        children: [
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Phone number'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _verifyPhoneNumber();
            },
            child: const Text('Verify Phone Number'),
          ),
          TextField(
            controller: _smsController,
            decoration: const InputDecoration(labelText: 'Verification code'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _signInWithPhoneNumber();
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyPhoneNumber() async {
    final phoneNumber = _phoneController.text;

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Automatic verification completed
        await _auth.signInWithCredential(credential);
        // Optionally, send a confirmation message here
      },
      verificationFailed: (FirebaseAuthException e) {
        // Handle the error
        print('Verification failed: ${e.message}');
      },
      codeSent: (String verificationId, int? resendToken) {
        // Code sent successfully
        setState(() {
          _verificationId = verificationId;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Auto retrieval timeout
        setState(() {
          _verificationId = verificationId;
        });
      },
    );
  }

  Future<void> _signInWithPhoneNumber() async {
    final smsCode = _smsController.text;
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId,
      smsCode: smsCode,
    );

    try {
      await _auth.signInWithCredential(credential);
      // Successfully signed in
      // Optionally, send a confirmation message here
    } catch (e) {
      // Handle sign-in error
      print('Sign-in failed: ${e.toString()}');
    }
  }
}
