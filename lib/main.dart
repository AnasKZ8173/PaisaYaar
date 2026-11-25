import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/services/local_push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await LocalPushService.initialize();

  runApp(
    const ProviderScope(
      child: SplitlyApp(),
    ),
  );
}
