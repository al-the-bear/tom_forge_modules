// ignore_for_file: avoid_print

import 'dart:io';
import 'package:analyzer/src/summary2/package_bundle_format.dart';

void main(List<String> args) {
  final bytes =
      File(args.isNotEmpty ? args[0] : 'assets/summaries/sdk_summary.sum')
          .readAsBytesSync();
  final bundle = PackageBundleReader(bytes);
  print('SDK Libraries: ${bundle.libraries.length}');
  for (var i = 0; i < 3 && i < bundle.libraries.length; i++) {
    final lib = bundle.libraries[i];
    print('Library $i: "${lib.uriStr}"');
    for (var j = 0; j < lib.units.length; j++) {
      print('  Unit [$j]: "${lib.units[j].uriStr}"');
    }
  }
}
