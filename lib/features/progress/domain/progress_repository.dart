import 'package:ceo_communication_trainer/core/types/app_models.dart';

abstract class ProgressRepository {
  ProgressSnapshot? get progress;
  DashboardSnapshot? get dashboard;
}
