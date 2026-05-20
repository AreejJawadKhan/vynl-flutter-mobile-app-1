import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../services/analytics_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isReady = false;

  /// True after the first [authStateChanges] event (session restore finished).
  bool get isReady => _isReady;

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  String get uid => currentUser?.uid ?? '';
  String get displayName => currentUser?.displayName ?? 'Music Fan';
  String get email => currentUser?.email ?? '';
  String? get photoUrl => currentUser?.photoURL;
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  AuthProvider() {
    _auth.authStateChanges().listen((user) {
      _isReady = true;
      AnalyticsService.setUser(user?.uid);
      notifyListeners();
    });
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email.trim());
  }

  static bool isValidPassword(String password) =>
      password.length >= 6;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Initialize GoogleSignIn
      await GoogleSignIn.instance.initialize();

      // Trigger the Google sign-in flow
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate(scopeHint: ['email', 'profile']);

      // Obtain auth details (idToken)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Obtain access token via the authorization client
      final GoogleSignInClientAuthorization clientAuth =
          await googleUser.authorizationClient.authorizeScopes(['email', 'profile']);

      // Create Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: clientAuth.accessToken,
      );

      final result = await _auth.signInWithCredential(credential);
      await _ensureUserProfile(result.user!);
      await AnalyticsService.logLogin(method: 'google');
      return result;
    } catch (e) {
      debugPrint('[AuthProvider] Google sign-in error: $e');
      return null;
    }
  }

  Future<UserCredential?> signInWithEmail(
      String email, String password) async {
    if (!isValidEmail(email)) {
      throw FirebaseAuthException(code: 'invalid-email');
    }
    if (!isValidPassword(password)) {
      throw FirebaseAuthException(code: 'weak-password');
    }
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      if (result.user != null) {
        await _ensureUserProfile(result.user!);
      }
      await AnalyticsService.logLogin(method: 'email');
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthProvider] Email sign-in error: ${e.code}');
      rethrow;
    }
  }

  Future<UserCredential?> registerWithEmail(
      String email, String password, String displayName) async {
    if (!isValidEmail(email)) {
      throw FirebaseAuthException(code: 'invalid-email');
    }
    if (!isValidPassword(password)) {
      throw FirebaseAuthException(code: 'weak-password');
    }
    final name = displayName.trim();
    if (name.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-display-name');
    }
    try {
      final result = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await result.user!.updateDisplayName(name);
      await result.user!.reload();
      await _ensureUserProfile(_auth.currentUser!);
      await _auth.currentUser?.sendEmailVerification();
      await AnalyticsService.logSignUp(method: 'email');
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthProvider] Register error: ${e.code}');
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (!isValidEmail(email)) {
      throw FirebaseAuthException(code: 'invalid-email');
    }
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user == null) return;
    await user.sendEmailVerification();
    await user.reload();
    notifyListeners();
  }

  Future<void> reloadUser() async {
    await currentUser?.reload();
    notifyListeners();
  }

  Future<void> signOut() async {
    await AnalyticsService.setUser(null);
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> _ensureUserProfile(User user) async {
    final ref = FirebaseDatabase.instance.ref('users/${user.uid}');
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      await ref.set({
        'uid': user.uid,
        'displayName': user.displayName ?? 'Music Fan',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'isPublic': true,
        'joinedAt': ServerValue.timestamp,
        'stats': {
          'likedSongs': 0,
          'roomsCreated': 0,
          'listeningTimeMs': 0,
        },
      });
    }
  }
}
