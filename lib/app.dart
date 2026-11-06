import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'features/home/advisor_home_screen.dart';

class AcademicAdvisorApp extends StatelessWidget {
  const AcademicAdvisorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'همراه تحصیلی',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(AppColors.seed),
          ),
          scaffoldBackgroundColor: const Color(AppColors.scaffold),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: EdgeInsets.zero,
          ),
        ),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: AdvisorHomeScreen(),
        ),
      );
}
