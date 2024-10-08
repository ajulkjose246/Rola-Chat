import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final UserCredential userCredential =
            await _auth.signInWithCredential(credential);

        // Create or update user document in Firestore
        await _createOrUpdateUserDocument(userCredential.user!);

        // Navigate to home screen or show success message
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      // Show error message to user
    }
  }

  Future<void> _signInWithPhone() async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneController.text,
        verificationCompleted: (PhoneAuthCredential credential) async {
          final UserCredential userCredential =
              await _auth.signInWithCredential(credential);

          // Create or update user document in Firestore
          await _createOrUpdateUserDocument(userCredential.user!);

          // Navigate to home screen or show success message
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Phone verification failed: $e');
          // Show error message to user
        },
        codeSent: (String verificationId, int? resendToken) {
          // Navigate to OTP input screen, passing verificationId
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      print('Error signing in with phone: $e');
      // Show error message to user
    }
  }

  Future<void> _createOrUpdateUserDocument(User user) async {
    final userDoc =
        FirebaseFirestore.instance.collection('Users').doc(user.uid);

    await userDoc.set({
      'email': user.email ?? '',
      'name': user.displayName ?? '',
      'photo': user.photoURL ?? '',
      'uid': user.uid,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFECE5DD), // WhatsApp-like background color
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo.png', // Add your app logo here
                  height: 100,
                  width: 100,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to RolaChat',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF075E54), // WhatsApp-like primary color
                  ),
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Enter your phone number',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon:
                        const Icon(Icons.phone, color: Color(0xFF075E54)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _signInWithPhone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF128C7E), // WhatsApp-like button color
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Continue', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'or',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon:
                      Image.asset('assets/images/google_logo.png', height: 24),
                  label: const Text('Sign in with Google'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Color(0xFF128C7E)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                const Text(
                  'By tapping Continue, you agree to our Terms of Service and Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
