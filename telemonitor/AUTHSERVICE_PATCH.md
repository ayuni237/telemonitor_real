# Add to `lib/services/auth_service.dart`

Paste this method inside the `AuthService` class — anywhere among the
other methods, for example just after `signOut()`.

```dart
  /// Sends a password reset email.
  ///
  /// Note the caller shows a deliberately generic confirmation regardless
  /// of outcome. Firebase does not reveal whether an address is
  /// registered, and neither should the interface: doing so would let
  /// anyone test which emails have accounts on the system.
  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }
```

That is the only change needed to `auth_service.dart` for this step.
