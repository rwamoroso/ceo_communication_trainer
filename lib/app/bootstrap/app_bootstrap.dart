import 'package:ceo_communication_trainer/app/bootstrap/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppBootstrap {
  static Future<AppConfig> initialize() async {
    final config = AppConfig.fromEnvironment();

    if (!config.useFakeBackend &&
        config.supabaseUrl != null &&
        config.supabaseAnonKey != null) {
      await Supabase.initialize(
        url: config.supabaseUrl!,
        anonKey: config.supabaseAnonKey!,
      );
    }

    return config;
  }
}
