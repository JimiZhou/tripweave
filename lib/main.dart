import 'dart:async';

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(TripWeaveApp(state: state));
  unawaited(state.refreshMusicCatalog());
  unawaited(state.restoreJourneyHistory());
  unawaited(state.checkForUpdate());
}
