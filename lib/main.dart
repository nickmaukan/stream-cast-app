import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/services/database_service.dart';
import 'core/services/notification_service.dart';
import 'features/browser/presentation/pages/home_page.dart';
import 'features/casting/presentation/bloc/casting_bloc.dart';
import 'features/history/presentation/history_bloc.dart';
import 'features/favorites/presentation/favorites_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize services
  final dbService = DatabaseService();
  await dbService.database; // Initialize DB

  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(MaukanCastApp(
    dbService: dbService,
    notificationService: notificationService,
  ));
}

class MaukanCastApp extends StatelessWidget {
  final DatabaseService dbService;
  final NotificationService notificationService;

  const MaukanCastApp({
    super.key,
    required this.dbService,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => CastingBloc(
            notificationService: notificationService,
          ),
        ),
        BlocProvider(
          create: (_) => HistoryBloc(db: dbService),
        ),
        BlocProvider(
          create: (_) => FavoritesBloc(db: dbService),
        ),
      ],
      child: MaterialApp(
        title: 'Maukan Cast',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomePage(),
      ),
    );
  }
}
