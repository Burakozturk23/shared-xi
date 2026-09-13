import 'dart:async';

import 'package:flutter/material.dart';

/// Explicit boundary for the 17B shell and the existing 17C game interiors.
/// Unnamed child routes inherit their entry route, including dialogs and setup
/// flows, so choosing light mode cannot put dark text on legacy dark canvases.
class LinkballRoute<T> extends MaterialPageRoute<T> {
  LinkballRoute({required super.builder, this.modern = true, super.settings});
  final bool modern;
}

class RouteAppearanceObserver extends NavigatorObserver {
  final legacy = ValueNotifier<bool>(false);
  final List<(Route<dynamic>, bool)> _routes = [];
  bool _disposed = false;

  void _publish() {
    final value = _routes.isNotEmpty && _routes.last.$2;
    scheduleMicrotask(() {
      if (!_disposed) legacy.value = value;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final old = _routes.isNotEmpty && _routes.last.$2;
    _routes.add((route, route is LinkballRoute ? !route.modern : old));
    _publish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.removeWhere((entry) => entry.$1 == route);
    _publish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.removeWhere((entry) => entry.$1 == route);
    _publish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = _routes.indexWhere((entry) => entry.$1 == oldRoute);
    if (index >= 0 && newRoute != null) {
      _routes[index] = (
        newRoute,
        newRoute is LinkballRoute ? !newRoute.modern : _routes[index].$2,
      );
    }
    _publish();
  }

  void dispose() {
    _disposed = true;
    legacy.dispose();
  }
}
