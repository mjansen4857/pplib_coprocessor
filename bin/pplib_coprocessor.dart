import 'dart:io';

import 'package:args/args.dart';
import 'package:pplib_coprocessor/pplib_coprocessor.dart';

void main(List<String> arguments) {
  var parser = ArgParser();

  parser.addOption('server');
  var results = parser.parse(arguments);

  var serverAddress = results['server'];
  if (serverAddress == null || serverAddress is! String) {
    print('Server IP adress was not provided. Usage: --server 10.TE.AM.2');
    exit(1);
  }

  runPathfinding(serverAddress);
}
