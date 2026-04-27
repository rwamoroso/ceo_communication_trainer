import 'package:ceo_communication_trainer/core/types/app_models.dart';

abstract class AuthRepository {
  AppUser? get currentUser;

  bool get isInPasswordRecovery;

  Future<void> signIn(String email, String password, {bool isSignUp = false});

  Future<void> signOut();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> updatePassword(String newPassword);
}
