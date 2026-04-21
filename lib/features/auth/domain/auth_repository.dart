import 'package:ceo_communication_trainer/core/types/app_models.dart';

abstract class AuthRepository {
  AppUser? get currentUser;

  Future<void> signIn(String email, String password, {bool isSignUp = false});

  Future<void> signOut();
}
