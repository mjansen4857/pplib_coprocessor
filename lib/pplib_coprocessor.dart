import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:nt4/nt4.dart';
import 'package:pplib_coprocessor/pathfinding/ad_star.dart';
import 'package:pplib_coprocessor/pathfinding/navgrid.dart';
import 'package:pplib_coprocessor/pathfinding/pathfinder.dart';

void runPathfinding(String serverAddress) async {
  print('Connecting to server at $serverAddress');
  NT4Client ntClient = NT4Client(
    serverBaseAddress: serverAddress,
    onConnect: () => print('Connected to NT'),
    onDisconnect: () => print('Lost Connection to NT'),
  );

  NT4Subscription navGridJsonSub = ntClient.subscribe(
      '/PPLibCoprocessor/RemoteADStar/navGrid',
      NT4SubscriptionOptions(periodicRateSeconds: 0.001, all: true));
  NT4Subscription startPosSub = ntClient.subscribe(
      '/PPLibCoprocessor/RemoteADStar/startPos',
      NT4SubscriptionOptions(periodicRateSeconds: 0.001, all: true));
  NT4Subscription goalPosSub = ntClient.subscribe(
      '/PPLibCoprocessor/RemoteADStar/goalPos',
      NT4SubscriptionOptions(periodicRateSeconds: 0.001, all: true));
  NT4Subscription dynamicObsSub = ntClient.subscribe(
      '/PPLibCoprocessor/RemoteADStar/dynamicObstacles',
      NT4SubscriptionOptions(periodicRateSeconds: 0.001, all: true));

  NT4Topic pathTopic = ntClient.publishNewTopic(
      '/PPLibCoprocessor/RemoteADStar/pathPoints', NT4TypeStr.typeFloat64Arr);

  print('Running RemoteADStar...');
  Pathfinder pathfinder = ADStar(pathGeneratedCallback: (points) {
    try {
      List<double> ntPoints = [];
      for (Point p in points) {
        ntPoints.add(p.x.toDouble());
        ntPoints.add(p.y.toDouble());
      }

      ntClient.addSample(pathTopic, ntPoints);
    } catch (_) {}
  });

  StreamSubscription navGridStream = navGridJsonSub.stream().listen((sample) {
    if (sample != null && sample is String) {
      try {
        pathfinder.setNavgrid(NavGrid.fromJson(jsonDecode(sample)));
      } catch (_) {}
    }
  });
  StreamSubscription startPosStream = startPosSub.stream().listen((sample) {
    if (sample != null && sample is List) {
      try {
        Point startPos = Point(sample[0] as num, sample[1] as num);
        pathfinder.setStartPosition(startPos);
      } catch (_) {}
    }
  });
  StreamSubscription goalPosStream = goalPosSub.stream().listen((sample) {
    if (sample != null && sample is List) {
      try {
        Point goalPos = Point(sample[0] as num, sample[1] as num);
        pathfinder.setGoalPosition(goalPos);
      } catch (_) {}
    }
  });
  StreamSubscription dynamicObsStream = dynamicObsSub.stream().listen((sample) {
    if (sample != null && sample is List) {
      try {
        // First two numbers are the robot's current position
        Point currentPos = Point(sample[0] as num, sample[1] as num);

        // Remaining points describe bounding boxes
        List<(Point, Point)> obs = [];
        for (int i = 2; i <= sample.length - 4; i += 4) {
          Point p1 = Point(sample[i] as num, sample[i + 1] as num);
          Point p2 = Point(sample[i + 2] as num, sample[i + 3] as num);
          obs.add((p1, p2));
        }

        pathfinder.setDynamicObstacles(obs, currentPos);
      } catch (_) {}
    }
  });

  await Future.wait([
    navGridStream.asFuture(),
    startPosStream.asFuture(),
    goalPosStream.asFuture(),
    dynamicObsStream.asFuture(),
  ], eagerError: true);
}
