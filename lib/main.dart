import 'app/presto_app.dart';
import 'bootstrap/app_bootstrap.dart';

export 'app/app_runtime_config.dart';
export 'app/presto_app.dart' show PrestoApp;
export 'app/runtime_stores.dart';
export 'app/startup_state.dart';
export 'app/system_ui_style.dart';
export 'pages/publish_offer_page.dart' show PublishOfferPage;
export 'pages/splash_screen.dart' show SplashScreen;
export 'services/offer_details_mapper.dart' show buildOfferDetailsOffer;
export 'services/presto_monitoring.dart' show PrestoMonitoring;
export 'services/region_resolver.dart' show inferRegionFromPostalCode;
export 'widgets/app_shell_widgets.dart' show CardShell, PrestoResponsiveFrame;
export 'widgets/audio_pipeline_badge.dart' show AudioPipelineBadge;

Future<void> main() => bootstrapPrestoApp(const PrestoApp());
