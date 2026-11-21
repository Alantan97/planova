/// Account boundary for the app. Screens call this, never a backend SDK, so
/// real Google sign-in (Firebase Auth + google_sign_in) can replace
/// [GuestAuthService] in one place later.
abstract interface class AuthService {
  /// Whether "Continue with Google" really signs in.
  bool get googleSignInAvailable;

  /// Signs in with Google. Throws [GoogleSignInUnavailable] while only the
  /// guest implementation exists; never asks for credentials itself.
  Future<SignedInUser> signInWithGoogle();
}

class SignedInUser {
  const SignedInUser({required this.id, this.displayName, this.email});
  final String id;
  final String? displayName;
  final String? email;
}

class GoogleSignInUnavailable implements Exception {
  const GoogleSignInUnavailable();
  @override
  String toString() =>
      'Google sign-in is not connected yet. Planova keeps your data on this device for now.';
}

/// Current implementation: no accounts. Data stays on the device.
class GuestAuthService implements AuthService {
  const GuestAuthService();

  @override
  bool get googleSignInAvailable => false;

  @override
  Future<SignedInUser> signInWithGoogle() =>
      Future.error(const GoogleSignInUnavailable());
}
