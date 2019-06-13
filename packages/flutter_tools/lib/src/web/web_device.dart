// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import '../application_package.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/platform.dart';
import '../base/process_manager.dart';
import '../build_info.dart';
import '../device.dart';
import '../globals.dart';
import '../project.dart';
import '../web/compile.dart';
import '../web/workflow.dart';
import 'chrome.dart';

class WebApplicationPackage extends ApplicationPackage {
  WebApplicationPackage(this.flutterProject) : super(id: flutterProject.manifest.appName);

  final FlutterProject flutterProject;

  @override
  String get name => flutterProject.manifest.appName;

  /// The location of the web source assets.
  Directory get webSourcePath => flutterProject.directory.childDirectory('web');
}

class WebDevice extends Device {
  WebDevice() : super('web');

  HttpServer _server;
  WebApplicationPackage _package;

  @override
  bool get supportsHotReload => true;

  @override
  bool get supportsHotRestart => true;

  @override
  bool get supportsStartPaused => true;

  @override
  bool get supportsFlutterExit => true;

  @override
  bool get supportsScreenshot => false;

  @override
  void clearLogs() { }

  @override
  DeviceLogReader getLogReader({ApplicationPackage app}) {
    return NoOpDeviceLogReader(app.name);
  }

  @override
  Future<bool> installApp(ApplicationPackage app) async => true;

  @override
  Future<bool> isAppInstalled(ApplicationPackage app) async => true;

  @override
  Future<bool> isLatestBuildInstalled(ApplicationPackage app) async => true;

  @override
  Future<bool> get isLocalEmulator async => false;

  @override
  bool isSupported() => flutterWebEnabled;

  @override
  String get name => 'web';

  @override
  DevicePortForwarder get portForwarder => const NoOpDevicePortForwarder();

  @override
  Future<String> get sdkNameAndVersion async {
    // See https://bugs.chromium.org/p/chromium/issues/detail?id=158372
    String version = 'unknown';
    if (platform.isWindows) {
      final ProcessResult result = await processManager.run(<String>[
        r'reg', 'query', 'HKEY_CURRENT_USER\\Software\\Google\\Chrome\\BLBeacon', '/v', 'version'
      ]);
      if (result.exitCode == 0) {
        final List<String> parts = result.stdout.split(RegExp(r'\s+'));
        if (parts.length > 2) {
          version = 'Google Chrome ' + parts[parts.length - 2];
        }
      }
    } else {
      final String chrome = findChromeExecutable();
      final ProcessResult result = await processManager.run(<String>[
        chrome,
        '--version',
      ]);
      if (result.exitCode == 0) {
        version = result.stdout;
      }
    }
    return version;
  }

  @override
  Future<LaunchResult> startApp(
    covariant WebApplicationPackage package, {
    String mainPath,
    String route,
    DebuggingOptions debuggingOptions,
    Map<String, Object> platformArgs,
    bool prebuiltApplication = false,
    bool usesTerminalUi = true,
    bool ipv6 = false,
  }) async {
    await buildWeb(
      package.flutterProject,
      fs.path.relative(mainPath, from: package.flutterProject.directory.path),
      debuggingOptions.buildInfo,
    );
    _package = package;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_basicAssetServer);
    printStatus('Serving assets from http:localhost:${_server.port}');
    await chromeLauncher.launch('http://localhost:${_server.port}');
    return LaunchResult.succeeded(observatoryUri: null);
  }

  // Note: we don't currently have a way to track which chrome processes
  // belong to the flutter tool, so we'll err on the side of caution by
  // keeping these open.
  @override
  Future<bool> stopApp(ApplicationPackage app) async {
    await _server?.close();
    _server = null;
    return true;
  }

  @override
  Future<TargetPlatform> get targetPlatform async => TargetPlatform.web_javascript;

  @override
  Future<bool> uninstallApp(ApplicationPackage app) async => true;

  Future<void> _basicAssetServer(HttpRequest request) async {
    if (request.method != 'GET') {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    // Resolve all get requests to the build/web/ or build/flutter_assets directory.
    final Uri uri = request.uri;
    File file;
    String contentType;
    if (uri.path == '/') {
      file = _package.webSourcePath.childFile('index.html');
      contentType = 'text/html';
    } else if (uri.path == '/main.dart.js') {
      file = fs.file(fs.path.join(getWebBuildDirectory(), 'main.dart.js'));
      contentType = 'text/javascript';
    } else {
      file = fs.file(fs.path.join(getAssetBuildDirectory(), uri.path.replaceFirst('/assets/', '')));
    }

    if (!file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    request.response.statusCode = HttpStatus.ok;
    if (contentType != null) {
      request.response.headers.add(HttpHeaders.contentTypeHeader, contentType);
    }
    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  @override
  bool isSupportedForProject(FlutterProject flutterProject) {
    return flutterProject.web.existsSync();
  }
}

class WebDevices extends PollingDeviceDiscovery {
  WebDevices() : super('web');

  final WebDevice _webDevice = WebDevice();

  @override
  bool get canListAnything => flutterWebEnabled;

  @override
  Future<List<Device>> pollingGetDevices() async {
    return <Device>[
      _webDevice,
    ];
  }

  @override
  bool get supportsPlatform => flutterWebEnabled;
}

@visibleForTesting
String parseVersionForWindows(String input) {
  return input.split(RegExp('\w')).last;
}
