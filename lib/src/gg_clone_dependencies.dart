// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:args/command_runner.dart';
import 'commands/clone_dependencies.dart';
import 'package:gg_log/gg_log.dart';

/// The command line interface for GgCloneDependencies
class GgCloneDependencies extends Command<dynamic> {
  /// Constructor
  GgCloneDependencies({required this.ggLog}) {
    addSubcommand(CloneDependencies(ggLog: ggLog));
  }

  /// The log function
  final GgLog ggLog;

  // ...........................................................................
  @override
  final name = 'ggCloneDependencies';
  @override
  final description = 'Add your description here.';
}
