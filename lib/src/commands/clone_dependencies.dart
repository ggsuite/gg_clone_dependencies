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
/// An example command
class CloneDependencies extends DirCommand<dynamic> {
  /// Constructor
  CloneDependencies({
    required super.ggLog,
  }) : super(
          name: 'clone-dependencies',
          description: 'Clones all dependencies to the current workspace',
        );

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

    // get the workspace directory
    Directory workspaceDir = projectDir.parent;

    Set<String> dependencies = <String>{};

    await cloneDependencies(workspaceDir, projectDir, dependencies, ggLog);
  }
}

// ...........................................................................
/// Process the node
Future<void> cloneDependencies(
  Directory workspaceDir,
  Directory projectDir,
  Set<String> processedNodes,
  GgLog ggLog,
) async {
  projectDir = correctDir(projectDir);
  final pubspec = File('${projectDir.path}/pubspec.yaml');

  final pubspecContent = await pubspec.readAsString();

  late Pubspec pubspecYaml;
  try {
    pubspecYaml = Pubspec.parse(pubspecContent);
  } catch (e) {
    throw Exception(red('Error parsing pubspec.yaml:') + e.toString());
  }

  /*// Load the YAML content as a Map
  final yamlMap = loadYaml(pubspecContent) as Map;

  // Check if the 'dependencies' section exists
  if (!yamlMap.containsKey('dependencies') &&
      !yamlMap.containsKey('dev_dependencies')) {
    return;
  }*/

  // Iterate all dependencies
  final keys = [
    ...pubspecYaml.dependencies.keys,
    ...pubspecYaml.devDependencies.keys,
  ];

  for (final dependency in keys) {
    if (processedNodes.contains(dependency)) {
      continue;
    }
    processedNodes.add(dependency);

    // check if dependency already exists
    if (await dependencyExists(workspaceDir, dependency, ggLog)) {
      continue;
    }

    // check if dependency is on github
    bool isOnGithub = await checkGithubOrigin(workspaceDir, dependency);
    if (!isOnGithub) {
      continue;
    }

    // clone dependency
    await cloneDependency(workspaceDir, dependency, ggLog);

    // execute cloneDependencies for dependency
    final dependencyDir = Directory('${workspaceDir.path}/$dependency');
    await cloneDependencies(workspaceDir, dependencyDir, processedNodes, ggLog);
  }
}

// ...........................................................................
/// Check if the dependency already exists in the workspace
Future<bool> dependencyExists(
  Directory workspaceDir,
  String dependency,
  GgLog ggLog,
) async {
  final dependencyDir = Directory('${workspaceDir.path}/$dependency');
  if (await dependencyDir.exists()) {
    ggLog(yellow('Dependency $dependency already exists in workspace.'));
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
String getPackageName(String pubspecContent) {
  late Pubspec pubspecYaml;
  try {
    pubspecYaml = Pubspec.parse(pubspecContent);
  } catch (e) {
    throw Exception(red('Error parsing pubspec.yaml:') + e.toString());
  }

  return pubspecYaml.name;
}
