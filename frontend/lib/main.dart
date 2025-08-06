import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/note_provider.dart';
import 'screens/main_tab_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/preferences_service.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 로컬 저장소 초기화
  await PreferencesService.init();
  
  runApp(const LittenApp());
}

class LittenApp extends StatelessWidget {
  const LittenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NoteProvider()),
      ],
      child: Consumer2<LocaleProvider, ThemeProvider>(
        builder: (context, localeProvider, themeProvider, child) {
          return MaterialApp(
            title: 'Litten',
            debugShowCheckedModeBanner: false,
            
            // 테마 설정
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            
            // 국제화 설정
            locale: localeProvider.locale,
            supportedLocales: AppConfig.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            
            // 네비게이션
            home: const AppInitializer(),
          );
        },
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  void _checkOnboardingStatus() async {
    // onboarding 완료 여부 확인
    final bool onboardingCompleted = PreferencesService.getBool('onboarding_completed') ?? false;
    
    // 짧은 지연 후 해당 화면으로 이동
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => onboardingCompleted 
              ? const MainTabScreen() 
              : const OnboardingScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.headphones,
              size: 80,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              '리튼 (Litten)',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '듣기 + 쓰기 통합 노트 앱',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}