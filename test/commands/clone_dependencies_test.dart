// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:gg_capture_print/gg_capture_print.dart';
import 'package:gg_log/gg_log.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import 'package:gg_clone_dependencies/src/commands/clone_dependencies.dart';

import '../test_helpers.dart';

void main() {
  final messages = <String>[];
  late CommandRunner<void> runner;

  Directory tempDir = Directory('');
  Directory dParseError = Directory('');
  Directory dWorkspaceSuccess = Directory('');
  Directory dCorrectYaml = Directory('');
  Directory dInvalidYaml = Directory('');
  Directory dInvalidYamlGetDependencies = Directory('');
  Directory dGetProjectDirWorkspace = Directory('');
  Directory dGetProjectDirNonExistentWorkspace = Directory('');

  setUp(() async {
    messages.clear();
    runner = CommandRunner<void>('clone', 'Description of clone command.');
    final myCommand = CloneDependencies(ggLog: messages.add);
    runner.addCommand(myCommand);

    tempDir = createTempDir('clone_dependencies_test');
    dParseError = createTempDir('parse_error', 'project');
    dWorkspaceSuccess = createTempDir('success');
    dCorrectYaml = createTempDir('correct_yaml', 'project');
    dInvalidYaml = createTempDir('invalid_yaml', 'project');
    dInvalidYamlGetDependencies =
        createTempDir('invalid_yaml_get_dependencies');
    dGetProjectDirWorkspace = createTempDir('get_project_dir');
    dGetProjectDirNonExistentWorkspace =
        createTempDir('get_project_dir_non_existent');
  });

  tearDown(() async {
    deleteDirs(
      [
        tempDir,
        dParseError,
        dWorkspaceSuccess,
        dCorrectYaml,
        dInvalidYaml,
        dInvalidYamlGetDependencies,
        dGetProjectDirWorkspace,
        dGetProjectDirNonExistentWorkspace,
      ],
    );
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
        await File(p.join(dParseError.path, 'pubspec.yaml'))
            .writeAsString('invalid yaml');

        await expectLater(
          runner.run(['clone-dependencies', '--input', dParseError.path]),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Error parsing pubspec.yaml'),
            ),
          ),
        );
      });

      test('should succeed and clone dependencies', () async {
        // Set up a mock workspace with projects and dependencies
        final projectDir =
            Directory(p.join(dWorkspaceSuccess.path, 'project1'));
        const dependencyName = 'dependency1';

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
          Directory dWorkspaceSuccess,
          String packageName, {
          Future<ProcessResult> Function(
            String,
            List<String>, {
            String? workingDirectory,
          })? processRun,
        }) async {
          return true;
        }

        // Mock the cloneDependency function to simulate cloning
        Future<void> mockCloneDependency(
          Directory dWorkspaceSuccess,
          String dependency,
          GgLog ggLog, {
          Future<ProcessResult> Function(
            String,
            List<String>, {
            String? workingDirectory,
          })? processRun,
        }) async {
          ggLog('Simulating cloning $dependency into workspace...');
          final dependencyDir =
              Directory(p.join(dWorkspaceSuccess.path, dependency));
          if (!await dependencyDir.exists()) {
            await dependencyDir.create(recursive: true);
          }
          // Simulate initializing a git repository
          await Process.run(
            'git',
            ['init'],
            workingDirectory: dependencyDir.path,
          );
        }

        // Create an instance of the command with mocked functions
        final myCommand = CloneDependencies(ggLog: messages.add)
          ..mockCheckGithubOrigin = mockCheckGithubOrigin
          ..mockCloneDependency = mockCloneDependency;

        // Run the command
        await myCommand.get(directory: projectDir, ggLog: messages.add);

        expect(messages[0], contains('Running clone-dependencies in'));
        expect(
          messages[1],
          contains('Simulating cloning dependency1 into workspace...'),
        );

        // Verify that the dependency was "cloned"
        final clonedDependencyDir =
            Directory(p.join(dWorkspaceSuccess.path, 'dependency1'));
        expect(await clonedDependencyDir.exists(), isTrue);
      });

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

        final exists = await dependencyExists(
          dependencyDir,
          dependencyName,
          ggLog: messages.add,
        );
        expect(exists, isTrue);
        expect(
          messages.last,
          contains('Dependency dependency1 already exists in workspace.'),
        );
      });

      test('should return false if dependency does not exist', () async {
        final workspaceDir = tempDir;
        final dependencyDir =
            Directory(p.join(workspaceDir.path, 'dependency3'));
        const dependencyName = 'dependency1';

        final exists = await dependencyExists(
          dependencyDir,
          dependencyName,
          ggLog: messages.add,
        );
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
      File pFile = File(p.join(dCorrectYaml.path, 'pubspec.yaml'));
      pFile.writeAsStringSync(pubspecContent);

      final packageName = getPackageName(dCorrectYaml);
      expect(packageName, equals('test_package'));
    });

    test('getPackageName should throw if pubspec.yaml cannot be parsed', () {
      const pubspecContent = 'invalid yaml';
      File pFile = File(p.join(dInvalidYaml.path, 'pubspec.yaml'));
      pFile.writeAsStringSync(pubspecContent);

      expect(
        () => getPackageName(dInvalidYaml),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Error parsing pubspec.yaml'),
          ),
        ),
      );
    });

    test('getDependencies should throw if pubspec.yaml cannot be parsed', () {
      const pubspecContent = 'invalid yaml';
      File pFile =
          File(p.join(dInvalidYamlGetDependencies.path, 'pubspec.yaml'));
      pFile.writeAsStringSync(pubspecContent);

      expect(
        () => getDependencies(dInvalidYamlGetDependencies),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Error parsing pubspec.yaml'),
          ),
        ),
      );
    });

    group('getProjectDir', () {
      test('should return the correct project directory if it exists', () {
        Directory projectDir =
            Directory(p.join(dGetProjectDirWorkspace.path, 'project1'));
        projectDir.createSync(recursive: true);
        File(p.join(projectDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: project1
version: 1.0.0
dependencies:
  dependency1: ^1.0.0
  ''');
        final result = getProjectDir('project1', dGetProjectDirWorkspace);
        expect(result, isNotNull);
        expect(result!.path, equals(projectDir.path));
      });

      test('should return null if the project directory does not exist', () {
        final result = getProjectDir(
          'non_existent_project',
          dGetProjectDirNonExistentWorkspace,
        );
        expect(result, isNull);
      });
    });
  });
}
