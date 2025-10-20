import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaizen/pages/analytics_aptitude_page.dart';
import 'package:kaizen/pages/assessment_page.dart';
import 'package:kaizen/pages/prompt_page.dart';
import 'package:kaizen/pages/results_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize intl locale data to fix "Lookup failed: format" errors
  await initializeDateFormatting('en', null);
  Intl.defaultLocale = 'en_US';

  // Load environment variables safely
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Could not load .env file: $e");
  }

  // Initialize Supabase client
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
      detectSessionInUri: true,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kaizen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[90],
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 1),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/prompt': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return PromptPage(instanceId: args['instance_id']);
        },
        '/results': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return ResultsPage(
            instanceId: args['instance_id'],
            title: args['title'],
          );
        },
        '/assessment': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return AssessmentPage(
            instanceId: args['instance_id'],
          );
        },
        '/analytics_aptitude': (context) => const AnalyticsAptitudePage(),
      },
    );
  }
}
