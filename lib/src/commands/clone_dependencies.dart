// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_args/gg_args.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_log/gg_log.dart';
import 'dart:io';
import 'package:gg_project_root/gg_project_root.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

// #############################################################################
/// Clone all dependencies of the project
class CloneDependencies extends DirCommand<dynamic> {
  /// Constructor
  CloneDependencies({
    required super.ggLog,
  }) : super(
          name: 'clone-dependencies',
          description: 'Clones all dependencies to the current workspace',
        );

  /// Mock for the checkGithubOrigin function
  Future<bool> Function(
    Directory,
    String, {
    Future<ProcessResult> Function(
      String,
      List<String>, {
      String? workingDirectory,
    })? processRun,
  }) mockCheckGithubOrigin = checkGithubOrigin;

  /// Mock for the cloneDependency function
  Future<void> Function(
    Directory,
    String,
    GgLog, {
    Future<ProcessResult> Function(
      String,
      List<String>, {
      String? workingDirectory,
    })? processRun,
  }) mockCloneDependency = cloneDependency;

  // ...........................................................................
  @override
  Future<void> get({required Directory directory, required GgLog ggLog}) async {
    ggLog('Running clone-dependencies in ${directory.path}');

    // get the project root
    String? root = await GgProjectRoot.get(directory.absolute.path);

    if (root == null) {
      throw Exception(red('No project root found'));
    }

    Directory projectDir = correctDir(Directory(root));
    String packageName = getPackageName(projectDir);

    // get the workspace directory
    Directory workspaceDir = projectDir.parent;

    Set<String> processedNodes = <String>{};
    Map<String, Directory> projectDirs = {packageName: projectDir};

    await cloneDependencies(
      workspaceDir,
      packageName,
      projectDirs,
      processedNodes,
      ggLog,
    );
  }

  // ...........................................................................
  /// Clone all dependencies of the project
  Future<void> cloneDependencies(
    Directory workspaceDir,
    String packageName,
    Map<String, Directory> projectDirs,
    Set<String> processedNodes,
    GgLog ggLog,
  ) async {
    final projectDir = correctDir(projectDirs[packageName]!);

    // Iterate all dependencies
    final keys = await getDependencies(projectDir);

    for (final dependency in keys) {
      if (processedNodes.contains(dependency)) {
        continue;
      }
      processedNodes.add(dependency);

      Directory dependencyDir = getProjectDir(dependency, workspaceDir) ??
          Directory('${workspaceDir.path}/$dependency');

      // check if dependency already exists
      bool exists =
          await dependencyExists(dependencyDir, dependency, ggLog: ggLog);

      // check if dependency is on github
      bool isOnGithub = await mockCheckGithubOrigin(workspaceDir, dependency);

      // clone dependency
      if (!exists && isOnGithub) {
        await mockCloneDependency(workspaceDir, dependency, ggLog);
      }

      dependencyDir = getProjectDir(dependency, workspaceDir) ??
          Directory('${workspaceDir.path}/$dependency');

      // check if dependency exists after cloning
      bool existsAfterCloning =
          await dependencyExists(dependencyDir, dependency);

      if (!existsAfterCloning) {
        continue;
      }

      // execute cloneDependencies for dependency
      projectDirs[dependency] = dependencyDir;
      await cloneDependencies(
        workspaceDir,
        dependency,
        projectDirs,
        processedNodes,
        ggLog,
      );
    }
  }
}

// ...........................................................................
/// Get the dependencies from the pubspec.yaml file
Future<List<String>> getDependencies(Directory projectDir) async {
  final pubspec = File('${projectDir.path}/pubspec.yaml');

  if (!pubspec.existsSync()) {
    return [];
  }

  final pubspecContent = await pubspec.readAsString();

  late Pubspec pubspecYaml;
  try {
    pubspecYaml = Pubspec.parse(pubspecContent);
  } catch (e) {
    throw Exception(red('Error parsing pubspec.yaml:') + e.toString());
  }

  // Iterate all dependencies
  return [
    ...pubspecYaml.dependencies.keys,
    ...pubspecYaml.devDependencies.keys,
  ];
}

// ...........................................................................
/// Check if the dependency already exists in the workspace
Future<bool> dependencyExists(
  Directory dependencyDir,
  String dependency, {
  GgLog? ggLog,
}) async {
  if (await dependencyDir.exists()) {
    ggLog?.call(yellow('Dependency $dependency already exists in workspace.'));
    return true;
  }
  return false;
}

// ...........................................................................
/// Clone the dependency from GitHub
Future<void> cloneDependency(
  Directory workspaceDir,
  String dependency,
  GgLog ggLog, {
  Future<ProcessResult> Function(
    String,
    List<String>, {
    String? workingDirectory,
  })? processRun,
}) async {
  processRun ??= Process.run;

  ggLog('Cloning $dependency into workspace...');
  final cloneResult = await processRun(
    'git',
    ['clone', 'git@github.com:inlavigo/$dependency.git'],
    workingDirectory: workspaceDir.path,
  );

  if (cloneResult.exitCode != 0) {
    throw Exception(
      'Failed to clone $dependency. Exit code: ${cloneResult.exitCode}',
    );
  }
}

// ...........................................................................
/// Check if the dependency exists on github
Future<bool> checkGithubOrigin(
  Directory workspaceDir,
  String packageName, {
  Future<ProcessResult> Function(
    String,
    List<String>, {
    String? workingDirectory,
  })? processRun,
}) async {
  processRun ??= Process.run;

  final repo = 'git@github.com:inlavigo/$packageName.git';

  final result = await processRun(
    'git',
    ['ls-remote', repo, 'origin'],
    workingDirectory: workspaceDir.path,
  );

  // coverage:ignore-start
  if (result.exitCode == 128) {
    return false;
  } else if (result.exitCode != 0) {
    throw Exception('Error while running "git ls-remote $repo origin".\n'
        'Exit code: ${result.exitCode}\n'
        'Error: ${result.stderr}\n');
  } else {
    return true;
  }
  // coverage:ignore-end
}

// ...........................................................................
/// Helper method to correct a directory
Directory correctDir(Directory directory) {
  if (directory.path.endsWith('\\.') || directory.path.endsWith('/.')) {
    directory =
        Directory(directory.path.substring(0, directory.path.length - 2));
  } else if (directory.path.endsWith('\\') || directory.path.endsWith('/')) {
    directory =
        Directory(directory.path.substring(0, directory.path.length - 1));
  }
  return directory;
}

// ...........................................................................
/// Get the package name from the pubspec.yaml file
String getPackageName(Directory projectDir) {
  final pubspec = File('${projectDir.path}/pubspec.yaml');

  final pubspecContent = pubspec.readAsStringSync();

  late Pubspec pubspecYaml;
  try {
    pubspecYaml = Pubspec.parse(pubspecContent);
  } catch (e) {
    throw Exception(red('Error parsing pubspec.yaml:') + e.toString());
  }

  return pubspecYaml.name;
}

// ...........................................................................
/// Get the project directory
Directory? getProjectDir(String packageName, Directory workspaceDir) {
  for (final entity in workspaceDir.listSync()) {
    if (entity is! Directory) {
      continue;
    }
    final pubspec = File('${entity.path}/pubspec.yaml');
    if (!pubspec.existsSync()) {
      continue;
    }
    if (getPackageName(entity) == packageName) {
      return entity;
    }
  }
  return null;
}
