import 'package:flutter/foundation.dart';

import '../api/debug_options.dart';
import '../repositories/network_simulator.dart';

/// Учебное меню «Отладка» в шапке: `__delay`, `__fail`.
/// Смена роли — через выход и вход под другой учётной записью (ПР5).
class DebugSettingsNotifier extends ChangeNotifier {
  DebugSettingsNotifier({this.options, this.simulator});

  final DebugOptions? options;
  final NetworkSimulator? simulator;

  bool get usesApi => options != null;

  bool get slowResponses => options?.slowResponses ?? false;
  bool get failResponses =>
      options?.failResponses ?? simulator?.failRequests ?? false;

  void toggleSlow() {
    final o = options;
    if (o != null) o.slowResponses = !o.slowResponses;
    notifyListeners();
  }

  void toggleFail() {
    final o = options;
    if (o != null) {
      o.failResponses = !o.failResponses;
    } else if (simulator != null) {
      simulator!.failRequests = !simulator!.failRequests;
    }
    notifyListeners();
  }
}
