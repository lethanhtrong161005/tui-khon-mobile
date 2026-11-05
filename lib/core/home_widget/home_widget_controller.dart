import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeWidgetAction { expense, income, quickRecord, scanReceipt }

class HomeWidgetRequest {
  const HomeWidgetRequest(this.id, this.action);
  final String id;
  final HomeWidgetAction action;

  static HomeWidgetRequest? parse(Object? value) {
    if (value is! Map || value['id'] is! String) return null;
    final id = value['id'] as String;
    final action = HomeWidgetAction.values
        .where((a) => a.name == value['action'])
        .firstOrNull;
    return id.isEmpty || action == null ? null : HomeWidgetRequest(id, action);
  }
}

abstract interface class HomeWidgetBridge {
  void listen(VoidCallback onAvailable);
  Future<Object?> takePendingAction();
  Future<void> clearPendingAction();
  Future<void> updateAppearance(Map<String, String> values);
  void dispose();
}

class PlatformHomeWidgetBridge implements HomeWidgetBridge {
  PlatformHomeWidgetBridge({this.enabled = true});
  final bool enabled;
  static const channel = MethodChannel('tui_khon/home_widget');
  bool get supported =>
      enabled && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void listen(VoidCallback onAvailable) {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'actionAvailable') onAvailable();
    });
  }

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    if (!supported) return null;
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      // A launcher/extension failure must not prevent normal notebook use.
      return null;
    }
  }

  @override
  Future<Object?> takePendingAction() => _call<Object>('takePendingAction');
  @override
  Future<void> clearPendingAction() async => _call<void>('clearPendingAction');
  @override
  Future<void> updateAppearance(Map<String, String> values) async =>
      _call<void>('updateAppearance', values);
  @override
  void dispose() {
    if (supported) channel.setMethodCallHandler(null);
  }
}

/// One pending request, latest wins. Never contains financial/account data.
class HomeWidgetController extends StateNotifier<HomeWidgetRequest?> {
  HomeWidgetController() : super(null);
  final _seen = <String>{};
  HomeWidgetRequest? _active;
  int _epoch = 0;
  bool get hasWork => state != null || _active != null;

  void receive(Object? raw) {
    final request = HomeWidgetRequest.parse(raw);
    if (request == null || !_seen.add(request.id)) return;
    if (_seen.length > 64) _seen.remove(_seen.first);
    if (_active?.action == request.action) return;
    state = request;
  }

  Future<void> poll(HomeWidgetBridge bridge) async {
    final epoch = _epoch;
    final raw = await bridge.takePendingAction();
    if (mounted && epoch == _epoch) receive(raw);
  }

  HomeWidgetRequest? begin() {
    if (_active != null) return null;
    final next = state;
    if (next != null) {
      _active = next;
      state = null;
    }
    return next;
  }

  void finish(String id) {
    if (_active?.id == id) _active = null;
  }

  void clear() {
    _epoch++;
    _active = null;
    state = null;
  }
}

// Only the native app entrypoint enables platform I/O. Standalone screens and
// tests can use the controller without depending on a running Android engine.
final homeWidgetEnabledProvider = Provider<bool>((ref) => false);
final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>((ref) =>
    PlatformHomeWidgetBridge(enabled: ref.watch(homeWidgetEnabledProvider)));
final homeWidgetControllerProvider =
    StateNotifierProvider<HomeWidgetController, HomeWidgetRequest?>(
        (ref) => HomeWidgetController());

/// Register the warm-launch callback before taking the cold-launch request.
final homeWidgetStartupProvider = FutureProvider<void>((ref) async {
  final bridge = ref.watch(homeWidgetBridgeProvider);
  final controller = ref.read(homeWidgetControllerProvider.notifier);
  ref.onDispose(bridge.dispose);
  bridge.listen(() => unawaited(controller.poll(bridge)));
  await controller.poll(bridge);
});

final homeWidgetForegroundProvider = StateProvider<bool>((ref) => true);

/// Wakes the dispatcher after any pushed page, dialog or sheet closes.
class AppNavigationObserver extends NavigatorObserver with ChangeNotifier {
  final _routes = <Route<dynamic>>[];
  bool get hasOverlays => _routes.length > 1;
  bool _scheduled = false;
  bool _disposed = false;

  void _changed() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final appNavigationObserverProvider =
    ChangeNotifierProvider<AppNavigationObserver>(
        (ref) => AppNavigationObserver());
