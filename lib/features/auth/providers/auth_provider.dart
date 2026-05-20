import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  String get uid => currentUser?.uid ?? '';
  String get displayName => currentUser?.displayName ?? 'Music Fan';
  String get email => currentUser?.email ?? '';
  String? get photoUrl => currentUser?.photoURL;

  AuthProvider() {
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

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
      await _createUserProfile(result.user!);
      return result;
    } catch (e) {
      debugPrint('[AuthProvider] Google sign-in error: $e');
      return null;
    }
  }

  Future<UserCredential?> signInWithEmail(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthProvider] Email sign-in error: ${e.code}');
      rethrow;
    }
  }

  Future<UserCredential?> registerWithEmail(
      String email, String password, String displayName) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await result.user!.updateDisplayName(displayName);
      await _createUserProfile(result.user!);
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthProvider] Register error: ${e.code}');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> _createUserProfile(User user) async {
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
