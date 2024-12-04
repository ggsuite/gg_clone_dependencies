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
  Directory dWorkspaceSuccessGit = Directory('');
  Directory dWorkspaceSuccessGitRef = Directory('');
  Directory dWorkspacePathDependency = Directory('');
  Directory dWorkspaceSdkDependency = Directory('');
  Directory dWorkspaceNoRepository = Directory('');
  Directory dCorrectYaml = Directory('');
  Directory dInvalidYaml = Directory('');
  Directory dInvalidYamlGetDependencies = Directory('');
  Directory dGetProjectDirWorkspace = Directory('');
  Directory dGetProjectDirNonExistentWorkspace = Directory('');
  Directory dTargetArgumentTest = Directory('');
  Directory dExcludeArgumentTest = Directory('');
  Directory dDirectArgumentTest = Directory('');
  Directory dAllArgumentTest = Directory('');

  setUp(() async {
    messages.clear();
    runner = CommandRunner<void>('clone', 'Description of clone command.');
    final myCommand = GithubActionsMock(ggLog: messages.add);
    runner.addCommand(myCommand);

    tempDir = createTempDir('clone_dependencies_test');
    dParseError = createTempDir('parse_error', 'project');
    dWorkspaceSuccess = createTempDir('success');
    dWorkspaceSuccessGit = createTempDir('success_git');
    dWorkspaceSuccessGitRef = createTempDir('success_git_ref');
    dWorkspacePathDependency = createTempDir('path_dependency');
    dWorkspaceSdkDependency = createTempDir('sdk_dependency');
    dWorkspaceNoRepository = createTempDir('no_repository');
    dCorrectYaml = createTempDir('correct_yaml', 'project');
    dInvalidYaml = createTempDir('invalid_yaml', 'project');
    dInvalidYamlGetDependencies =
        createTempDir('invalid_yaml_get_dependencies');
    dGetProjectDirWorkspace = createTempDir('get_project_dir');
    dGetProjectDirNonExistentWorkspace =
        createTempDir('get_project_dir_non_existent');
    dTargetArgumentTest = createTempDir('target_argument_test');
    dExcludeArgumentTest = createTempDir('exclude_argument_test');
    dDirectArgumentTest = createTempDir('direct_argument_test');
    dAllArgumentTest = createTempDir('all_argument_test');
  });

  tearDown(() async {
    deleteDirs(
      [
        tempDir,
        dParseError,
        dWorkspaceSuccess,
        dWorkspaceSuccessGit,
        dWorkspaceSuccessGitRef,
        dWorkspacePathDependency,
        dWorkspaceSdkDependency,
        dWorkspaceNoRepository,
        dCorrectYaml,
        dInvalidYaml,
        dInvalidYamlGetDependencies,
        dGetProjectDirWorkspace,
        dGetProjectDirNonExistentWorkspace,
        dTargetArgumentTest,
        dExcludeArgumentTest,
        dDirectArgumentTest,
        dAllArgumentTest,
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

      group('should throw when', () {
        test('project root is not found', () async {
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

        test('pubspec.yaml cannot be parsed', () async {
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
      });

      group('should succeed and', () {
        test('clone dependencies', () async {
          // Set up a mock workspace with projects and dependencies
          final projectDir = createSubdir(dWorkspaceSuccess, 'project1');
          const dependencyName = 'http';

          // Create a pubspec.yaml for the project
          await File(p.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: project1
version: 1.0.0
dependencies:
  $dependencyName: ^1.0.0
''');

          final myCommand = GithubActionsMock(ggLog: messages.add);

          // Run the command
          await myCommand.get(directory: projectDir, ggLog: messages.add);

          expect(messages[0], contains('Running clone-dependencies in'));
          expect(
            messages[1],
            contains('Simulating cloning $dependencyName into workspace...'),
          );

          // Verify that the dependency was "cloned"
          final clonedDependencyDir =
              Directory(p.join(dWorkspaceSuccess.path, dependencyName));
          expect(await clonedDependencyDir.exists(), isTrue);
        });

        test('clone git dependencies', () async {
          // Set up a mock workspace with projects and dependencies
          final projectDir = createSubdir(dWorkspaceSuccessGit, 'project1');
          const dependencyName = 'http';

          // Create a pubspec.yaml for the project
          await File(p.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: project1
version: 1.0.0
dependencies:
  $dependencyName:
    git: https://github.com/inlavigo/gg_clone_dependencies.git
''');

          final myCommand = GithubActionsMock(ggLog: messages.add);

          // Run the command
          await myCommand.get(directory: projectDir, ggLog: messages.add);

          expect(messages[0], contains('Running clone-dependencies in'));
          expect(
            messages[1],
            contains('Simulating cloning $dependencyName into workspace...'),
          );

          // Verify that the dependency was "cloned"
          final clonedDependencyDir =
              Directory(p.join(dWorkspaceSuccessGit.path, dependencyName));
          expect(await clonedDependencyDir.exists(), isTrue);
        });

        test('clone git dependencies with ref', () async {
          // Set up a mock workspace with projects and dependencies
          final projectDir = createSubdir(dWorkspaceSuccessGitRef, 'project1');
          const dependencyName = 'http';

          // Create a pubspec.yaml for the project
          await File(p.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: project1
version: 1.0.0
dependencies:
  $dependencyName:
    git: 
      url: https://github.com/inlavigo/gg_clone_dependencies.git
      ref: dev
''');

          await runner.run([
            'clone-dependencies',
            '--input',
            projectDir.path,
            '--no-checkout-main',
          ]);

          expect(messages[0], contains('Running clone-dependencies in'));
          expect(
            messages[1],
            contains('Simulating cloning $dependencyName into workspace...'),
          );

          // Verify that the dependency was "cloned"
          final clonedDependencyDir =
              Directory(p.join(dWorkspaceSuccessGitRef.path, dependencyName));
          expect(await clonedDependencyDir.exists(), isTrue);
        });

        test('print when repository does not exist', () async {
          // Set up a mock workspace with projects and dependencies
          final projectDir = createSubdir(dWorkspaceNoRepository, 'project1');
          const dependencyName = 'dependency1';

          // Create a pubspec.yaml for the project
          await File(p.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: project1
version: 1.0.0
dependencies:
  $dependencyName: ^1.0.0
''');

          final myCommand = GithubActionsMock(ggLog: messages.add);

          // Run the command
          await myCommand.get(directory: projectDir, ggLog: messages.add);

          expect(messages[0], contains('Running clone-dependencies in'));
          expect(
            messages[1],
            contains(
              'Dependency dependency1 does not '
              'have a repository url and cannot be cloned.',
            ),
          );

          // Verify that the dependency was not cloned
          final clonedDependencyDir =
              Directory(p.join(dWorkspaceNoRepository.path, 'dependency1'));
          expect(await clonedDependencyDir.exists(), isFalse);
        });

        test(
            'clone dependencies into the specified target '
            'directory when target argument is provided', () async {
          // Set up a mock workspace with a project
          final projectDir = createSubdir(dTargetArgumentTest, 'project1');
          const dependencyName = 'http';

          // Create a pubspec.yaml for the project
          await File(p.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: project1
version: 1.0.0
dependencies:
  $dependencyName: ^1.0.0
''');

          // Specify a target directory
          final targetDir = createSubdir(dTargetArgumentTest, 'custom_target');

          // Run the command with the target argument
          await runner.run([
            'clone-dependencies',
            '--target',
            targetDir.path,
            '--input',
            projectDir.path,
          ]);

          expect(messages[0], contains('Running clone-dependencies in'));
          expect(
            messages[1],
            contains('Simulating cloning $dependencyName into workspace...'),
          );

          // Verify that the dependency was "cloned" into the target directory
          final clonedDependencyDir =
              Directory(p.join(targetDir.path, dependencyName));
          expect(await clonedDependencyDir.exists(), isTrue);
        });

        test(
            'exclude specified dependencies '
            'when exclude argument is provided', () async {
          // Set up a mock workspace with a project
          final projectDir = createSubdir(dExcludeArgumentTest, 'project1');
          const dependencyToExclude = 'http';
          const dependencyToInclude = 'path';

          // Create a pubspec.yaml for the project
          await File(p.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: project1
version: 1.0.0
dependencies:
  $dependencyToExclude: ^1.0.0
  $dependencyToInclude: ^1.0.0
''');

          // Run the command with the exclude argument
          await runner.run([
            'clone-dependencies',
            '--exclude',
            dependencyToExclude,
            '--input',
            projectDir.path,
          ]);

          expect(messages[0], contains('Running clone-dependencies in'));

          // Verify that the excluded dependency was not cloned
          final excludedDependencyDir =
              Directory(p.join(dExcludeArgumentTest.path, dependencyToExclude));
          expect(await excludedDependencyDir.exists(), isFalse);

          // Verify that the other dependency was cloned
          final includedDependencyDir =
              Directory(p.join(dExcludeArgumentTest.path, dependencyToInclude));
          expect(await includedDependencyDir.exists(), isTrue);
        });

        test(
            'only clone direct dependencies '
            'when direct argument is provided', () async {
          // Set up a mock workspace with a project and nested dependencies
          final projectDir = createSubdir(dDirectArgumentTest, 'project1');
          final directDepDir = createSubdir(dAllArgumentTest, 'http');
          const directDependency = 'http';
          const transitiveDependency =
              'async'; // Let's assume 'http' depends on 'async'

          // Create a pubspec.yaml for the project
          await File(p.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: project1
version: 1.0.0
dependencies:
  $directDependency: ^1.0.0
''');

          // Create a pubspec.yaml for the direct dependency
          await File(p.join(directDepDir.path, 'pubspec.yaml'))
              .writeAsString('''
name: $directDependency
version: 1.0.0
dependencies:
  $transitiveDependency: ^1.0.0
''');

          // Run the command with the direct argument
          await runner.run([
            'clone-dependencies',
            '--direct',
            '--input',
            projectDir.path,
          ]);

          expect(messages[0], contains('Running clone-dependencies in'));

          // Verify that the direct dependency was cloned
          final directDependencyDir =
              Directory(p.join(dDirectArgumentTest.path, directDependency));
          expect(await directDependencyDir.exists(), isTrue);

          // Verify that transitive dependencies were not cloned
          final transitiveDependencyDir =
              Directory(p.join(dDirectArgumentTest.path, transitiveDependency));
          expect(await transitiveDependencyDir.exists(), isFalse);
        });

        test('clone all dependencies when all argument is provided as true',
            () async {
          // Set up a mock workspace with a project and nested dependencies
          final projectDir = createSubdir(dAllArgumentTest, 'project1');
          final directDepDir = createSubdir(dAllArgumentTest, 'http');
          const directDependency = 'http';
          const transitiveDependency =
              'async'; // Let's assume 'http' depends on 'async'

          // Create a pubspec.yaml for the project
          await File(p.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: project1
version: 1.0.0
dependencies:
  $directDependency: ^1.0.0
''');

          // Create a pubspec.yaml for the direct dependency
          await File(p.join(directDepDir.path, 'pubspec.yaml'))
              .writeAsString('''
name: $directDependency
version: 1.0.0
dependencies:
  $transitiveDependency: ^1.0.0
''');

          // Run the command with the all argument (which defaults to true)
          await runner.run([
            'clone-dependencies',
            '--all',
            '--input',
            projectDir.path,
          ]);

          expect(messages[0], contains('Running clone-dependencies in'));

          // Verify that the direct dependency was cloned
          final directDependencyDir =
              Directory(p.join(dAllArgumentTest.path, directDependency));
          expect(await directDependencyDir.exists(), isTrue);

          // Verify that transitive dependencies were also cloned
          final transitiveDependencyDir =
              Directory(p.join(dAllArgumentTest.path, transitiveDependency));
          expect(await transitiveDependencyDir.exists(), isTrue);
        });
      });

      group('should skip cloning if', () {
        test('dependency is PathDependency', () async {
          // Set up a mock workspace with projects and dependencies
          final projectDir = createSubdir(dWorkspacePathDependency, 'project1');
          const dependencyName = 'dependency1';

          // Create a pubspec.yaml for the project
          await File(p.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: project1
version: 1.0.0
dependencies:
  $dependencyName:
    path: ../dependency1
''');

          final myCommand = GithubActionsMock(ggLog: messages.add);

          // Run the command
          await myCommand.get(directory: projectDir, ggLog: messages.add);

          expect(messages[0], contains('Running clone-dependencies in'));
          expect(
            messages[1],
            contains('Dependency dependency1 is a path '
                'dependency and cannot be cloned.'),
          );
        });

        test('dependency is SdkDependency', () async {
          // Set up a mock workspace with projects and dependencies
          final projectDir = createSubdir(dWorkspaceSdkDependency, 'project1');

          // Create a pubspec.yaml for the project
          await File(p.join(projectDir.path, 'pubspec.yaml')).writeAsString('''
name: project1
version: 1.0.0
dependencies:
  flutter2:
    sdk: flutter2
''');

          final myCommand = GithubActionsMock(ggLog: messages.add);

          // Run the command
          await myCommand.get(directory: projectDir, ggLog: messages.add);

          expect(messages[0], contains('Running clone-dependencies in'));
          expect(
            messages[1],
            contains('Dependency flutter2 is a sdk '
                'dependency and cannot be cloned.'),
          );
        });

        test('dependency already exists', () async {
          // Set up a mock workspace with projects and dependencies
          final workspaceDir = tempDir;
          final projectDir = createSubdir(workspaceDir, 'project1');
          const dependencyName = 'dependency1';
          final dependencyDir =
              Directory(p.join(workspaceDir.path, dependencyName));

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
          dependencyDir: dependencyDir,
          dependency: dependencyName,
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
          dependencyDir: dependencyDir,
          dependency: dependencyName,
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

        final result =
            await CloneDependencies(ggLog: messages.add).checkGithubOrigin(
          workspaceDir: workspaceDir,
          repositoryUrl: packageName,
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

        final result =
            await CloneDependencies(ggLog: messages.add).checkGithubOrigin(
          workspaceDir: workspaceDir,
          repositoryUrl: packageName,
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
          CloneDependencies(ggLog: messages.add).checkGithubOrigin(
            workspaceDir: workspaceDir,
            repositoryUrl: packageName,
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

        await CloneDependencies(ggLog: messages.add).cloneDependency(
          workspaceDir: workspaceDir,
          dependency: dependencyName,
          repositoryUrl: 'git@github.com:inlavigo/$dependencyName.git',
          ggLog: messages.add,
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
          CloneDependencies(ggLog: messages.add).cloneDependency(
            workspaceDir: workspaceDir,
            dependency: dependencyName,
            repositoryUrl: 'git@github.com:inlavigo/$dependencyName.git',
            ggLog: messages.add,
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
        final result = getProjectDir(
          packageName: 'project1',
          workspaceDir: dGetProjectDirWorkspace,
        );
        expect(result, isNotNull);
        expect(result!.path, equals(projectDir.path));
      });

      test('should return null if the project directory does not exist', () {
        final result = getProjectDir(
          packageName: 'non_existent_project',
          workspaceDir: dGetProjectDirNonExistentWorkspace,
        );
        expect(result, isNull);
      });
    });
  });
}

class GithubActionsMock extends CloneDependencies {
  GithubActionsMock({
    required super.ggLog,
  });

  @override
  Future<bool> checkGithubOrigin({
    required Directory workspaceDir,
    required String repositoryUrl,
    Future<ProcessResult> Function(
      String,
      List<String>, {
      String? workingDirectory,
    })? processRun,
  }) async {
    return true;
  }

  @override
  Future<void> cloneDependency({
    required Directory workspaceDir,
    required String dependency,
    required String repositoryUrl,
    required GgLog ggLog,
    String? reference,
    Future<ProcessResult> Function(
      String,
      List<String>, {
      String? workingDirectory,
    })? processRun,
  }) async {
    ggLog('Simulating cloning $dependency into workspace...');
    final dependencyDir = Directory(p.join(workspaceDir.path, dependency));
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
}
