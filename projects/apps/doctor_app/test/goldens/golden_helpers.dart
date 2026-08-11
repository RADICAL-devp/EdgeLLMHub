import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Standard phone-like viewport for goldens.
///
/// Call at the start of every golden test; registers resets automatically.
void usePhoneViewport(WidgetTester tester, {double textScale = 1.0}) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (textScale != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
}

ThemeData appTheme({Brightness brightness = Brightness.light}) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: brightness,
      ),
      useMaterial3: true,
    );

const appLocalizationsDelegates = [
  FlutterQuillLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const appSupportedLocales = [
  Locale('en'),
  Locale('es'),
];

/// Builds the app shell used by golden tests.
///
/// Pages that navigate via `context.push`/`context.go` need [router];
/// otherwise [child] is shown as the home widget.
Widget goldenApp({
  required Widget child,
  GoRouter? router,
  Brightness brightness = Brightness.light,
}) {
  final theme = appTheme(brightness: brightness);
  if (router != null) {
    return MaterialApp.router(
      title: 'Doctor Note App',
      routerConfig: router,
      theme: theme,
      themeMode: ThemeMode.light,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
    );
  }
  return MaterialApp(
    title: 'Doctor Note App',
    home: child,
    theme: theme,
    themeMode: ThemeMode.light,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: appSupportedLocales,
  );
}

/// Pump [child] and compare against `goldens/<name>[_dark].png`.
Future<void> matchGolden(
  WidgetTester tester,
  Widget child, {
  required String name,
  Brightness brightness = Brightness.light,
  GoRouter? router,
  bool settle = true,
}) async {
  usePhoneViewport(tester);
  await tester.pumpWidget(goldenApp(
    child: child,
    router: router,
    brightness: brightness,
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final suffix = brightness == Brightness.dark ? '_dark' : '';
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name$suffix.png'),
  );
}
