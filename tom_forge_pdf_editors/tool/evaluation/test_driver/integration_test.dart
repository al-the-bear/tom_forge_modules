// Copyright (c) 2026 Peter Nicolai Alexis Kyaw
// SPDX-License-Identifier: BSD-3-Clause

/// The driver `flutter drive --profile` runs the harness with; the harness
/// writes its results itself.
library;

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(timeout: const Duration(hours: 2));
