// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:gg_capture_print/gg_capture_print.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import 'package:gg_clone_dependencies/src/commands/clone_dependencies.dart';

void main() {
  final messages = <String>[];
  late CommandRunner<void> runner;

  Directory tempDir = Directory('');

  setUp(() async {
    messages.clear();
    runner = CommandRunner<void>('clone', 'Description of clone command.');
    final myCommand = CloneDependencies(ggLog: messages.add);
    runner.addCommand(myCommand);

    tempDir = await Directory.systemTemp.createTemp('clone_dependencies_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CloneDependencies Command', () {
    group('run()', () {
      test('should print a usage description when called with --help',
          () async {
        capturePrint(
          ggLog: messages.add,
          code: () => runner.run(
            ['clone-dependencies', '--help'],
          ),
        );

        expect(
          messages.last,
          contains('Clones all dependencies to the current workspace'),
        );
      });

      test('should throw when project root is not found', () async {
        await expectLater(
          runner.run(['clone-dependencies', '--input', tempDir.path]),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('No project root found'),
            ),
          ),
        );
      });

      test('should throw when pubspec.yaml cannot be parsed', () async {
        // Create a pubspec.yaml with invalid content in tempDir
        final projectDir = Directory(p.join(tempDir.path, 'project'));
        await projectDir.create(recursive: true);
        await File(p.join(projectDir.path, 'pubspec.yaml'))
            .writeAsString('invalid yaml');

        await expectLater(
          runner.run(['clone-dependencies', '--input', projectDir.path]),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Error parsing pubspec.yaml'),
            ),
          ),
        );
      });

      /*test('should succeed and clone dependencies', () async {
        // Set up a mock workspace with projects and dependencies
        final workspaceDir = tempDir;
        final projectDir = Directory(p.join(workspaceDir.path, 'project1'));
        const dependencyName = 'dependency1';
        final dependencyDir =
            Directory(p.join(workspaceDir.path, dependencyName));

        // Create the project directory
        await projectDir.create(recursive: true);
        // Create a pubspec.yaml for the project
        await File(p.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: project1
version: 1.0.0
dependencies:
  $dependencyName: ^1.0.0
''');

        // Mock the checkGithubOrigin function to always return true
        Future<bool> mockCheckGithubOrigin(
            Directory workspaceDir, String packageName) async {
          return true;
        }

        // Mock the cloneDependency function to simulate cloning
        Future<void> mockCloneDependency(
          Directory workspaceDir,
          String dependency,
          GgLog ggLog,
        ) async {
          ggLog('Simulating cloning $dependency into workspace...');
          final dependencyDir =
              Directory(p.join(workspaceDir.path, dependency));
          if (!await dependencyDir.exists()) {
            await dependencyDir.create(recursive: true);
          }
          // Simulate initializing a git repository
          await Process.run('git', ['init'],
              workingDirectory: dependencyDir.path);
        }

        // Run the command with the mocked functions
        await runner.run([
          'clone-dependencies',
          '--input',
          projectDir.path,
          '--mock',
        ], {
          'checkGithubOrigin': mockCheckGithubOrigin,
          'cloneDependency': mockCloneDependency,
        });

        expect(messages[0], contains('Running clone-dependencies in'));
        expect(messages[1],
            contains('Simulating cloning dependency1 into workspace...'));

        // Verify that the dependency was "cloned"
        final clonedDependencyDir =
            Directory(p.join(workspaceDir.path, 'dependency1'));
        expect(await clonedDependencyDir.exists(), isTrue);
      });*/

      test('should skip cloning if dependency already exists', () async {
        // Set up a mock workspace with projects and dependencies
        final workspaceDir = tempDir;
        final projectDir = Directory(p.join(workspaceDir.path, 'project1'));
        const dependencyName = 'dependency1';
        final dependencyDir =
            Directory(p.join(workspaceDir.path, dependencyName));

        // Create the project directory
        await projectDir.create(recursive: true);
        // Create a pubspec.yaml for the project
        await File(p.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: project1
version: 1.0.0
dependencies:
  $dependencyName: ^1.0.0
''');

        // Simulate that the dependency already exists in the workspace
        await dependencyDir.create(recursive: true);

        await runner.run(['clone-dependencies', '--input', projectDir.path]);

        expect(messages[0], contains('Running clone-dependencies in'));
        expect(
          messages[1],
          contains('Dependency dependency1 already exists in workspace.'),
        );
      });
    });
  });

  group('Helper Functions', () {
    group('dependencyExists', () {
      test('should return true if dependency exists', () async {
        final workspaceDir = tempDir;
        const dependencyName = 'dependency1';
        final dependencyDir =
            Directory(p.join(workspaceDir.path, dependencyName));
        await dependencyDir.create(recursive: true);

        final exists =
            await dependencyExists(workspaceDir, dependencyName, messages.add);
        expect(exists, isTrue);
        expect(
          messages.last,
          contains('Dependency dependency1 already exists in workspace.'),
        );
      });

      test('should return false if dependency does not exist', () async {
        final workspaceDir = tempDir;
        const dependencyName = 'dependency1';

        final exists =
            await dependencyExists(workspaceDir, dependencyName, messages.add);
        expect(exists, isFalse);
      });
    });

    group('checkGithubOrigin', () {
      test('should return true if repository exists on GitHub', () async {
        // Mock the Process.run to simulate git ls-remote
        Future<ProcessResult> mockProcessRun(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
          bool includeParentEnvironment = true,
          bool runInShell = false,
          ProcessStartMode mode = ProcessStartMode.normal,
        }) async {
          return ProcessResult(0, 0, 'mock output', '');
        }

        final workspaceDir = tempDir;
        const packageName = 'dependency1';

        final result = await checkGithubOrigin(
          workspaceDir,
          packageName,
          processRun: mockProcessRun,
        );
        expect(result, isTrue);
      });

      test('should return false if repository does not exist on GitHub',
          () async {
        // Mock the Process.run to simulate git ls-remote failure
        Future<ProcessResult> mockProcessRun(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
          bool includeParentEnvironment = true,
          bool runInShell = false,
          ProcessStartMode mode = ProcessStartMode.normal,
        }) async {
          return ProcessResult(0, 128, '', 'mock error');
        }

        final workspaceDir = tempDir;
        const packageName = 'dependency1';

        final result = await checkGithubOrigin(
          workspaceDir,
          packageName,
          processRun: mockProcessRun,
        );
        expect(result, isFalse);
      });

      test('should throw exception on unexpected git error', () async {
        // Mock the Process.run to simulate git ls-remote unexpected error
        Future<ProcessResult> mockProcessRun(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
          bool includeParentEnvironment = true,
          bool runInShell = false,
          ProcessStartMode mode = ProcessStartMode.normal,
        }) async {
          return ProcessResult(0, 1, '', 'mock error');
        }

        final workspaceDir = tempDir;
        const packageName = 'dependency1';

        await expectLater(
          checkGithubOrigin(
            workspaceDir,
            packageName,
            processRun: mockProcessRun,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Error while running "git ls-remote'),
            ),
          ),
        );
      });
    });

    group('cloneDependency', () {
      test('should clone dependency successfully', () async {
        // Mock the Process.run to simulate git clone
        Future<ProcessResult> mockProcessRun(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
          bool includeParentEnvironment = true,
          bool runInShell = false,
          ProcessStartMode mode = ProcessStartMode.normal,
        }) async {
          return ProcessResult(0, 0, 'mock output', '');
        }

        final workspaceDir = tempDir;
        const dependencyName = 'dependency1';

        await cloneDependency(
          workspaceDir,
          dependencyName,
          messages.add,
          processRun: mockProcessRun,
        );
        expect(
          messages.last,
          contains('Cloning dependency1 into workspace...'),
        );
      });

      test('should throw exception if git clone fails', () async {
        // Mock the Process.run to simulate git clone failure
        Future<ProcessResult> mockProcessRun(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
          bool includeParentEnvironment = true,
          bool runInShell = false,
          ProcessStartMode mode = ProcessStartMode.normal,
        }) async {
          return ProcessResult(0, 1, '', 'mock error');
        }

        final workspaceDir = tempDir;
        const dependencyName = 'dependency1';

        await expectLater(
          cloneDependency(
            workspaceDir,
            dependencyName,
            messages.add,
            processRun: mockProcessRun,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to clone dependency1'),
            ),
          ),
        );
      });
    });

    test('correctDir should remove trailing slashes and dots', () {
      final dirWithDot = Directory('/path/to/project/.');
      final dirWithSlash = Directory('/path/to/project/');
      final dirClean = Directory('/path/to/project');

      expect(correctDir(dirWithDot).path, equals('/path/to/project'));
      expect(correctDir(dirWithSlash).path, equals('/path/to/project'));
      expect(correctDir(dirClean).path, equals('/path/to/project'));
    });

    test('getPackageName should return the package name from pubspec.yaml', () {
      const pubspecContent = '''
name: test_package
version: 1.0.0
dependencies:
  dependency1: ^1.0.0
''';
      final packageName = getPackageName(pubspecContent);
      expect(packageName, equals('test_package'));
    });

    test('getPackageName should throw if pubspec.yaml cannot be parsed', () {
      const pubspecContent = 'invalid yaml';
      expect(
        () => getPackageName(pubspecContent),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Error parsing pubspec.yaml'),
          ),
        ),
      );
    });
  });
}
