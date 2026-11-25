import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'core/l10n/app_localizations.dart';
import 'core/l10n/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/local_push_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/notifications/data/notification_model.dart';
import 'features/notifications/providers/notifications_provider.dart';

class SplitlyApp extends ConsumerStatefulWidget {
  const SplitlyApp({super.key});

  @override
  ConsumerState<SplitlyApp> createState() => _SplitlyAppState();
}

class _SplitlyAppState extends ConsumerState<SplitlyApp> {
  final Set<String> _shownPushIds = {};

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    ref.listen<AsyncValue<List<AppNotificationModel>>>(
      notificationsStreamProvider,
      (prev, next) {
        final items = next.valueOrNull;
        if (items == null) return;
        if (prev?.valueOrNull == null) {
          // Seed existing IDs on initial load so we don't spam old alerts.
          for (final n in items) {
            _shownPushIds.add(n.id);
          }
          return;
        }
        for (final n in items) {
          if (!n.isRead && _shownPushIds.add(n.id)) {
            LocalPushService.show(
              id: n.id.hashCode,
              title: n.title,
              body: n.body,
            );
          }
        }
      },
    );

    return MaterialApp.router(
      title: 'PocketYaar BETA',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(languageCode: locale.languageCode),
      darkTheme: AppTheme.dark(languageCode: locale.languageCode),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
