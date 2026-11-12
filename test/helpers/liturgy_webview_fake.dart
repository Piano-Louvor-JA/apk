import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class LiturgyWebViewFake extends WebViewPlatform {
  final controllers = <LiturgyWebControllerFake>[];
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = LiturgyWebControllerFake(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _Widget(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _Navigation(params);
}

class LiturgyWebControllerFake extends PlatformWebViewController {
  LiturgyWebControllerFake(super.params) : super.implementation();
  String html = '', url = '', result = '"<p>Texto <b>formatado</b></p>"';
  final scripts = <String>[];
  final channels = <String, JavaScriptChannelParams>{};
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channels[params.name] = params;
  }

  @override
  Future<void> loadHtmlString(String value, {String? baseUrl}) async {
    html = value;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    url = params.uri.toString();
  }

  @override
  Future<void> loadFile(String path) async {
    url = path;
  }

  @override
  Future<void> runJavaScript(String script) async {
    scripts.add(script);
  }

  @override
  Future<Object> runJavaScriptReturningResult(String script) async {
    scripts.add(script);
    return result;
  }

  @override
  Future<void> reload() async {}
  @override
  Future<bool> canGoBack() async => false;
}

class _Widget extends PlatformWebViewWidget {
  _Widget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: Key('fake-web-content'));
}

class _Navigation extends PlatformNavigationDelegate {
  _Navigation(super.params) : super.implementation();
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {}
}
