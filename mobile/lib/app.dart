import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/settings/preferencias.dart';
import 'core/theme/app_theme.dart';

class UbsFacilApp extends ConsumerWidget {
  const UbsFacilApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final escala = ref.watch(preferenciasProvider.select((p) => p.escalaTexto));

    return MaterialApp.router(
      title: 'UBS Fácil',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // "Texto maior": soma-se à configuração de fonte do próprio celular
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final base = mq.textScaler.scale(1);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear((base * escala).clamp(1.0, 2.0))),
          child: child!,
        );
      },
    );
  }
}
