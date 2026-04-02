import 'package:get_it/get_it.dart';
import '../core/services/casting_engine.dart';
import '../core/services/database_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/video_detector_service.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Services
  getIt.registerLazySingleton<DatabaseService>(() => DatabaseService());
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());
  getIt.registerLazySingleton<VideoDetectorService>(() => VideoDetectorService());
  getIt.registerLazySingleton<CastingEngine>(() => ChromecastEngine());

  // Initialize
  await getIt<DatabaseService>().database;
  await getIt<NotificationService>().initialize();
}
