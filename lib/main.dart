import 'package:flutter/material.dart';
import 'app/theme.dart';
import 'screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KeraniSawitApp());
}

class KeraniSawitApp extends StatelessWidget {
  const KeraniSawitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kerani Sawit',
      theme: AppTheme.light,
      home: const MainShell(),
    );
  }
}
