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
import 'dart:convert';
import 'package:http/http.dart' as http;

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

    for (MapEntry<String, Dependency> dependency in keys) {
      String dependencyName = dependency.key;

      if (processedNodes.contains(dependencyName)) {
        continue;
      }
      processedNodes.add(dependencyName);

      Directory dependencyDir = getProjectDir(dependencyName, workspaceDir) ??
          Directory('${workspaceDir.path}/$dependencyName');

      // check if dependency already exists
      bool exists =
          await dependencyExists(dependencyDir, dependencyName, ggLog: ggLog);

      if (!exists) {
        // get the repository url
        String? repositoryUrl;
        if (dependency.value is HostedDependency) {
          repositoryUrl = await getRepositoryUrl(dependencyName);
        } else if (dependency.value is GitDependency) {
          repositoryUrl = (dependency.value as GitDependency).url.toString();
        } else if (dependency.value is PathDependency) {
          // PathDependency is not supported
          ggLog.call(
            yellow(
              'Dependency $dependencyName is a path '
              'dependency and cannot be cloned.',
            ),
          );
          continue;
        } else if (dependency.value is SdkDependency) {
          // SdkDependency is not supported
          ggLog.call(
            yellow(
              'Dependency $dependencyName is a sdk '
              'dependency and cannot be cloned.',
            ),
          );
          continue;
        }

        if (repositoryUrl == null) {
          ggLog.call(
            yellow(
              'Dependency $dependencyName does not have a '
              'repository url and cannot be cloned.',
            ),
          );
          continue;
        }

        // check if dependency is on github
        bool isOnGithub = await checkGithubOrigin(workspaceDir, repositoryUrl);

        // clone dependency
        if (isOnGithub) {
          await cloneDependency(
            workspaceDir,
            dependencyName,
            repositoryUrl,
            ggLog,
          );

          dependencyDir = getProjectDir(dependencyName, workspaceDir) ??
              Directory('${workspaceDir.path}/$dependencyName');

          // check if dependency exists after cloning
          bool existsAfterCloning =
              await dependencyExists(dependencyDir, dependencyName);

          if (!existsAfterCloning) {
            continue;
          }
        }
      }

      // execute cloneDependencies for dependency
      projectDirs[dependencyName] = dependencyDir;
      await cloneDependencies(
        workspaceDir,
        dependencyName,
        projectDirs,
        processedNodes,
        ggLog,
      );
    }
  }

  // ...........................................................................
  /// Check if the dependency exists on github
  Future<bool> checkGithubOrigin(
    Directory workspaceDir,
    String repositoryUrl, {
    Future<ProcessResult> Function(
      String,
      List<String>, {
      String? workingDirectory,
    })? processRun,
  }) async {
    processRun ??= Process.run;

    final result = await processRun(
      'git',
      ['ls-remote', repositoryUrl, 'origin'],
      workingDirectory: workspaceDir.path,
    );

    // coverage:ignore-start
    if (result.exitCode == 128) {
      return false;
    } else if (result.exitCode != 0) {
      throw Exception(
          'Error while running "git ls-remote $repositoryUrl origin".\n'
          'Exit code: ${result.exitCode}\n'
          'Error: ${result.stderr}\n');
    } else {
      return true;
    }
    // coverage:ignore-end
  }

  // ...........................................................................
  /// Clone the dependency from GitHub
  Future<void> cloneDependency(
    Directory workspaceDir,
    String dependency,
    String repositoryUrl,
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
      ['clone', repositoryUrl],
      workingDirectory: workspaceDir.path,
    );

    if (cloneResult.exitCode != 0) {
      throw Exception(
        'Failed to clone $dependency. Exit code: ${cloneResult.exitCode}',
      );
    }
  }
}

Map<File, Pubspec> _pubspecCache = {};

// ...........................................................................
/// Get the dependencies from the pubspec.yaml file
Future<List<MapEntry<String, Dependency>>> getDependencies(
  Directory projectDir,
) async {
  if (!pubspecExists(projectDir)) {
    return [];
  }

  Pubspec pubspecYaml = getPubspecYaml(projectDir);

  // Iterate all dependencies
  List<MapEntry<String, Dependency>> allDeps = [
    ...pubspecYaml.dependencies.entries,
    ...pubspecYaml.devDependencies.entries,
  ];
  return allDeps;
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
String getPackageName(Directory projectDir) => getPubspecYaml(projectDir).name;

// ...........................................................................
/// Fetches the GitHub repository URL of a package from pub.dev.
///
/// Returns `null` if the package does not
/// exist or the repository URL is not available.
Future<String?> getRepositoryUrl(String packageName) async {
  final url = 'https://pub.dev/api/packages/$packageName';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);

    // coverage:ignore-start
    final repositoryUrl = data['latest']['pubspec']['repository'] as String?;
    if (repositoryUrl != null) {
      return repositoryUrl;
    }

    // If the repository URL is not available, try to get the homepage URL.
    final homepage = data['latest']['pubspec']['homepage'] as String?;
    if (homepage != null && homepage.contains('github.com')) {
      return homepage;
    }
    // coverage:ignore-end

    return null;
  } else {
    // Package not found or an error occurred.
    return null;
  }
}

// ...........................................................................
/// Get the pubspec.yaml file
Pubspec getPubspecYaml(Directory projectDir) {
  final pubspec = File('${projectDir.path}/pubspec.yaml');

  // coverage:ignore-start
  if (_pubspecCache.containsKey(pubspec)) {
    return _pubspecCache[pubspec]!;
  }
  // coverage:ignore-end

  late Pubspec pubspecYaml;
  final pubspecContent = pubspec.readAsStringSync();

  try {
    pubspecYaml = Pubspec.parse(pubspecContent);
    _pubspecCache[pubspec] = pubspecYaml;
  } catch (e) {
    throw Exception(red('Error parsing pubspec.yaml:') + e.toString());
  }

  return pubspecYaml;
}

// ...........................................................................
/// Check if the pubspec.yaml file exists
bool pubspecExists(Directory projectDir) =>
    File('${projectDir.path}/pubspec.yaml').existsSync();

// ...........................................................................
/// Get the project directory
Directory? getProjectDir(String packageName, Directory workspaceDir) {
  for (final entity in workspaceDir.listSync()) {
    if (entity is! Directory) {
      continue;
    }
    final pubspec = File('${entity.path}/pubspec.yaml');
    if (!_pubspecCache.containsKey(pubspec) && !pubspec.existsSync()) {
      continue;
    }
    if (getPackageName(entity) == packageName) {
      return entity;
    }
  }
  return null;
}
