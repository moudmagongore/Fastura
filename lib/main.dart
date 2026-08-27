import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/core/constants/app_constants.dart';
import 'app/core/services/auth_service.dart';
import 'app/core/services/firestore_service.dart';
import 'app/core/services/session_controller.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Les deux plateformes initialisent déjà l'app Firebase nativement
  // (`google-services.json` sur Android, `GoogleService-Info.plist` sur iOS).
  // Rappeler `initializeApp` par-dessus est sans effet **tant que les options
  // passées sont les mêmes** ; sinon on récolte
  // `[core/duplicate-app] A Firebase App named "[DEFAULT]" already exists`.
  // C'est `DefaultFirebaseOptions.currentPlatform` qui doit être juste — le
  // garde ci-dessous ne protège de rien au premier lancement, où la liste
  // Dart est encore vide alors que l'app native existe déjà.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await GetStorage.init();
  await initializeDateFormatting(AppConstants.defaultLocale);

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Services permanents. L'ordre compte : SessionController s'abonne à
  // AuthService et lit Firestore dès sa construction.
  Get.put(ThemeController(), permanent: true);
  Get.put(AuthService(), permanent: true);
  Get.put(FirestoreService(), permanent: true);
  Get.put(SessionController(), permanent: true);

  runApp(const FasturaApp());
}

class FasturaApp extends StatelessWidget {
  const FasturaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>();

    // Obx enveloppe GetMaterialApp : au changement de thème tout l'arbre est
    // reconstruit, ce qui force la ré-évaluation des couleurs adaptatives
    // de AppColors.
    return Obx(
      () => GetMaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: theme.mode.value,
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
        defaultTransition: Transition.cupertino,
        // L'app est monolingue : le français est la seule langue déclarée,
        // et les délégués fournissent les libellés du framework
        // (calendriers, « Annuler », noms de mois).
        locale: AppConstants.locale,
        fallbackLocale: AppConstants.locale,
        supportedLocales: const [AppConstants.locale],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
