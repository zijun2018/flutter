// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/version.dart';
import 'package:flutter_tools/src/web/chrome.dart';
import 'package:flutter_tools/src/web/workflow.dart';
import 'package:mockito/mockito.dart';
import 'package:process/process.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/testbed.dart';

void main() {
  group('WebWorkflow', () {
    Testbed testbed;
    MockPlatform noEnvironment;
    MockPlatform notSupported;
    MockPlatform windows;
    MockPlatform linux;
    MockPlatform macos;
    MockProcessManager mockProcessManager;
    MockFlutterVersion unstable;
    MockFlutterVersion stable;
    WebWorkflow workflow;

    setUpAll(() {
      unstable = MockFlutterVersion(false);
      stable = MockFlutterVersion(true);
      noEnvironment = MockPlatform(environment: const <String, String>{});
      notSupported = MockPlatform(linux: false, windows: false, macos: false);
      windows = MockPlatform(windows: true);
      linux = MockPlatform(linux: true);
      macos = MockPlatform(macos: true);
      workflow = const WebWorkflow();
      mockProcessManager = MockProcessManager();
      testbed = Testbed(setup: () async {
        fs.file('chrome').createSync();
        when(mockProcessManager.canRun('chrome')).thenReturn(true);
      }, overrides: <Type, Generator>{
        FlutterVersion: () => unstable,
        ProcessManager: () => mockProcessManager,
      });
    });

    test('does not apply if FLUTTER_WEB is not true', ()=> testbed.run(() {
      expect(workflow.appliesToHostPlatform, false);
      expect(workflow.canLaunchDevices, false);
      expect(workflow.canListDevices, false);
      expect(workflow.canListEmulators, false);
    }, overrides: <Type, Generator>{
      Platform: () => noEnvironment,
    }));

    test('Applies on Linux', () => testbed.run(() {
      expect(workflow.appliesToHostPlatform, true);
      expect(workflow.canLaunchDevices, true);
      expect(workflow.canListDevices, true);
      expect(workflow.canListEmulators, false);
    }, overrides: <Type, Generator>{
      Platform: () => linux,
    }));

    test('Applies on macOS', () => testbed.run(() {
      expect(workflow.appliesToHostPlatform, true);
      expect(workflow.canLaunchDevices, true);
      expect(workflow.canListDevices, true);
      expect(workflow.canListEmulators, false);
    }, overrides: <Type, Generator>{
      Platform: () => macos,
    }));

    test('Applies on Windows', () => testbed.run(() {
      expect(workflow.appliesToHostPlatform, true);
      expect(workflow.canLaunchDevices, true);
      expect(workflow.canListDevices, true);
      expect(workflow.canListEmulators, false);
    }, overrides: <Type, Generator>{
      Platform: () => windows,
    }));

    test('does not apply on other platforms', () => testbed.run(() {
      expect(workflow.appliesToHostPlatform, false);
      expect(workflow.canLaunchDevices, false);
      expect(workflow.canListDevices, false);
      expect(workflow.canListEmulators, false);
    }, overrides: <Type, Generator>{
      Platform: () => notSupported,
    }));

    test('does not apply on stable brnach', () => testbed.run(() {
      expect(workflow.appliesToHostPlatform, false);
      expect(workflow.canLaunchDevices, false);
      expect(workflow.canListDevices, false);
      expect(workflow.canListEmulators, false);
    }, overrides: <Type, Generator>{
      Platform: () => macos,
      FlutterVersion: () => stable,
    }));
  });
}

class MockFlutterVersion extends Mock implements FlutterVersion {
  MockFlutterVersion(this.isStable);

  @override
  final bool isStable;
}

class MockProcessManager extends Mock implements ProcessManager {}

class MockPlatform extends Mock implements Platform {
  MockPlatform(
      {this.windows = false,
      this.macos = false,
      this.linux = false,
      this.environment = const <String, String>{
        'FLUTTER_WEB': 'true',
        kChromeEnvironment: 'chrome',
      }});

  final bool windows;
  final bool macos;
  final bool linux;

  @override
  final Map<String, String> environment;

  @override
  bool get isLinux => linux;

  @override
  bool get isMacOS => macos;

  @override
  bool get isWindows => windows;
}
