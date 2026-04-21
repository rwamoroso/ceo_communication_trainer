import 'package:ceo_communication_trainer/features/auth/domain/auth_repository.dart';
import 'package:ceo_communication_trainer/features/profile/domain/profile_repository.dart';
import 'package:ceo_communication_trainer/features/progress/domain/progress_repository.dart';
import 'package:ceo_communication_trainer/features/training_session/domain/training_repository.dart';
import 'package:flutter/foundation.dart';

abstract class AppService extends ChangeNotifier
    implements
        AuthRepository,
        ProfileRepository,
        TrainingRepository,
        ProgressRepository {
  bool get isLoading;
}
