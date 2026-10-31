import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/services/settings_service.dart';
import 'core/ui/app_routes.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/notes/note_detail_page.dart';
import 'features/notes/new_note_page.dart';
import 'features/notes/notes_list_page.dart';
import 'features/notes/recording_page.dart';
import 'features/notes/search_page.dart';
import 'features/notes/structured_note_page.dart';
import 'features/notes/transcript_page.dart';
import 'features/settings/settings_page.dart';
import 'features/setup/setup_page.dart';
import 'features/welcome/welcome_page.dart';

GoRouter createAppRouter(SettingsService settings) {
  return GoRouter(
    initialLocation: settings.hasCompletedOnboarding
        ? AppRoutes.dashboard
        : AppRoutes.welcome,
    redirect: (context, state) {
      final onboarded = settings.hasCompletedOnboarding;
      final path = state.uri.path;
      final onWelcome = path == AppRoutes.welcome;
      final onSetup = path == AppRoutes.setup;

      if (!onboarded && !onWelcome && !onSetup) {
        return AppRoutes.welcome;
      }
      if (onboarded && onWelcome) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: AppRoutes.setup,
        builder: (context, state) => const SetupPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.notes,
        builder: (context, state) => const NotesPage(),
      ),
      GoRoute(
        path: AppRoutes.newNote,
        builder: (context, state) => const NewNotePage(),
      ),
      GoRoute(
        path: '/notes/:id/record',
        builder: (context, state) =>
            RecordingPage(noteId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/notes/:id/transcript',
        builder: (context, state) =>
            TranscriptPage(noteId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/notes/:id/structured',
        builder: (context, state) =>
            StructuredNotePage(noteId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/notes/:id',
        builder: (context, state) =>
            NoteDetailPage(noteId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 48),
              const SizedBox(height: 12),
              const Text(
                'This page is not available. Return to the dashboard to '
                'continue.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const Text('Go to dashboard'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DoctorApp extends StatefulWidget {
  const DoctorApp({super.key, required this.settings, this.startupError});

  final SettingsService settings;
  final String? startupError;

  @override
  State<DoctorApp> createState() => _DoctorAppState();
}

class _DoctorAppState extends State<DoctorApp> {
  late final GoRouter _router = createAppRouter(widget.settings);

  @override
  Widget build(BuildContext context) {
    final lightTheme = buildAppTheme(Brightness.light);
    final darkTheme = buildAppTheme(Brightness.dark);

    if (widget.startupError != null) {
      return MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
        home: _StartupFailurePage(
          details: kDebugMode ? widget.startupError : null,
        ),
      );
    }

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('hi')],
      builder: (context, child) {
        final scaler = MediaQuery.textScalerOf(context);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: scaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 2.0),
          ),
          child: child!,
        );
      },
    );
  }
}

ThemeData buildAppTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00695C),
    brightness: brightness,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    visualDensity: VisualDensity.standard,
  );
  final isLight = brightness == Brightness.light;
  return base.copyWith(
    scaffoldBackgroundColor: isLight ? const Color(0xFFF6FAF8) : scheme.surface,
    appBarTheme: base.appBarTheme.copyWith(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: isLight ? const Color(0xFFF6FAF8) : scheme.surface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: isLight ? 0.8 : 0.4),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(
        alpha: isLight ? 0.35 : 0.2,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
  );
}

class _StartupFailurePage extends StatelessWidget {
  const _StartupFailurePage({this.details});

  final String? details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.memory_outlined,
                    size: 56,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'On-device AI could not start',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The native inference runtime failed to initialize. Close and '
                    'restart the app. This app requires an arm64 device (iOS 15 '
                    'or Android 10+). If the problem continues, reinstall the app '
                    'to restore the model runtime.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (details != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        details!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
