import 'dart:async';

import 'package:test/test.dart';
// ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart';
// ignore: implementation_imports
import 'package:test_api/src/backend/state.dart' as test_api;

import '../test/app_test.dart' as app_test;
import '../test/configuration_test.dart' as configuration_test;
import '../test/credentials_test.dart' as credentials_test;
import '../test/dynamic_realm_test.dart' as dynamic_realm_test;
import '../test/list_test.dart' as list_test;
import '../test/migration_test.dart' as migration_test;
import '../test/realm_object_test.dart' as realm_object_test;
import '../test/realm_test.dart' as realm_test;
import '../test/results_test.dart' as results_test;
import '../test/session_test.dart' as session_test;
import '../test/subscription_test.dart' as subscription_test;
import '../test/user_test.dart' as user_test;

Future<String> main(List<String> args) async {
  final Completer<String> completer = Completer<String>();

  try {
    final List<String> failedTests = [];

    await app_test.main(args);
    await configuration_test.main(args);
    await credentials_test.main(args);
    await dynamic_realm_test.main(args);
    await list_test.main(args);
    await migration_test.main(args);
    await realm_object_test.main(args);
    await realm_test.main(args);
    await results_test.main(args);
    await session_test.main(args);
    await subscription_test.main(args);
    await user_test.main(args);

    tearDown(() {
      if (Invoker.current?.liveTest.state.result == test_api.Result.error || Invoker.current?.liveTest.state.result == test_api.Result.failure) {
        failedTests.add(Invoker.current!.liveTest.individualName);
      }
    });

    tearDownAll(() {
      if (failedTests.isNotEmpty) {
        completer.complete(failedTests.join('\n'));
      } else {
        completer.complete('');
      }
    });
  } catch (e) {
    completer.complete(e.toString());
  }

  return completer.future;
}
