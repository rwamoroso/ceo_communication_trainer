import 'package:ceo_communication_trainer/app/bootstrap/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to Supabase for this project', () {
    final config = AppConfig.fromEnvironment();

    expect(config.backendMode, AppBackendMode.supabase);
    expect(config.useFakeBackend, isFalse);
    expect(config.supabaseUrl, kDefaultSupabaseUrl);
    expect(config.supabaseAnonKey, kDefaultSupabasePublishableKey);
  });
}
