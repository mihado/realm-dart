////////////////////////////////////////////////////////////////////////////////
//
// Copyright 2021 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////////

import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as _path;
import 'package:test/test.dart' hide test;
import 'package:test/test.dart' as testing;
import 'package:args/args.dart';
import '../lib/realm.dart';
import '../lib/src/cli/atlas_apps/baas_client.dart';
import '../lib/src/native/realm_core.dart';
import '../lib/src/configuration.dart';

part 'test.g.dart';

@RealmModel()
class _Car {
  @PrimaryKey()
  late String make;
}

@RealmModel()
class _Person {
  late String name;
}

@RealmModel()
class _Dog {
  @PrimaryKey()
  late String name;

  late int? age;

  _Person? owner;
}

@RealmModel()
class _Team {
  late String name;
  late List<_Person> players;
  late List<int> scores;
}

@RealmModel()
class _Student {
  @PrimaryKey()
  late int number;
  late String? name;
  late int? yearOfBirth;
  late _School? school;
}

@RealmModel()
class _School {
  @PrimaryKey()
  late String name;
  late String? city;
  List<_Student> students = [];
  late _School? branchOfSchool;
  late List<_School> branches;
}

@RealmModel()
@MapTo("myRemappedClass")
class $RemappedClass {
  @MapTo("primitive_property")
  late String remappedProperty;

  @MapTo("list-with-dashes")
  late List<$RemappedClass> listProperty;
}

@RealmModel()
class _Task {
  @PrimaryKey()
  @MapTo('_id')
  late ObjectId id;
}

@RealmModel()
class _Schedule {
  @PrimaryKey()
  @MapTo('_id')
  late ObjectId id;
  final tasks = <_Task>[];
}

@RealmModel()
class _AllTypes {
  late String stringProp;
  late bool boolProp;
  late DateTime dateProp;
  late double doubleProp;
  late ObjectId objectIdProp;
  late Uuid uuidProp;
  late int intProp;

  late String? nullableStringProp;
  late bool? nullableBoolProp;
  late DateTime? nullableDateProp;
  late double? nullableDoubleProp;
  late ObjectId? nullableObjectIdProp;
  late Uuid? nullableUuidProp;
  late int? nullableIntProp;
}

@RealmModel()
class _LinksClass {
  @PrimaryKey()
  late Uuid id;

  late _LinksClass? link;
  late List<_LinksClass> list;
}

@RealmModel()
class _AllCollections {
  late List<String> strings;
  late List<bool> bools;
  late List<DateTime> dates;
  late List<double> doubles;
  late List<ObjectId> objectIds;
  late List<Uuid> uuids;
  late List<int> ints;

  late List<String?> nullableStrings;
  late List<bool?> nullableBools;
  late List<DateTime?> nullableDates;
  late List<double?> nullableDoubles;
  late List<ObjectId?> nullableObjectIds;
  late List<Uuid?> nullableUuids;
  late List<int?> nullableInts;
}

@RealmModel()
class _NullableTypes {
  @PrimaryKey()
  @MapTo('_id')
  late ObjectId id;

  late ObjectId differentiator;

  late String? stringProp;
  late bool? boolProp;
  late DateTime? dateProp;
  late double? doubleProp;
  late ObjectId? objectIdProp;
  late Uuid? uuidProp;
  late int? intProp;
}

@RealmModel()
class _Event {
  @PrimaryKey()
  @MapTo('_id')
  late ObjectId id;
  @MapTo('stringQueryField')
  late String? name;
  @MapTo('boolQueryField')
  late bool? isCompleted;
  @MapTo('intQueryField')
  late int? durationInMinutes;
  late String? assignedTo;
}

@RealmModel()
class _Party {
  // no primary key!
  _Friend? host;
  late int year;
  final guests = <_Friend>[];
  _Party? previous;
}

@RealmModel()
class _Friend {
  @PrimaryKey()
  late String name;
  var age = 42;
  _Friend? bestFriend;
  final friends = <_Friend>[];
}

@RealmModel()
class _When {
  late DateTime dateTimeUtc;
  late String locationName; // tz database/Olson name
}

@RealmModel()
class _Player {
  @PrimaryKey()
  late String name;
  _Game? game;
  final scoresByRound = <int?>[]; // null means player didn't finish
}

@RealmModel()
class _Game {
  final winnerByRound = <_Player>[]; // null means no winner yet
  int get rounds => winnerByRound.length;
}

String? testName;
Map<String, String?> arguments = {};
final baasApps = <String, BaasApp>{};
final _openRealms = Queue<Realm>();
const String argBaasUrl = "BAAS_URL";
const String argBaasCluster = "BAAS_CLUSTER";
const String argBaasApiKey = "BAAS_API_KEY";
const String argBaasPrivateApiKey = "BAAS_PRIVATE_API_KEY";
const String argBaasProjectId = "BAAS_PROJECT_ID";
const String argDifferentiator = "BAAS_DIFFERENTIATOR";

String testUsername = "realm-test@realm.io";
String testPassword = "123456";
const String publicRSAKeyForJWTValidation = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvNHHs8T0AHD7SJ+CKvVR
leeJa4wqYTnaVYV+5bX9FmFXVoN+vHbMLEteMvSw4L3kSRZdcqxY7cTuhlpAvkXP
Yq6qSI+bW8T4jGW963uCc83UhVMx4MH/PzipAlfcPjVO2u4c+dmpgZQpgEmA467u
tauXUhmTsGpgNg2Gvc61B7Ny4LphshsyrfaJ9WjA/NM6LOmEBW3JPNcVG2qyU+gt
O8BM8KOSx9wGyoGs4+OusvRkJizhPaIwa3FInLs4r+xZW9Bp6RndsmVECtvXRv5d
87ztpg6o3DZJRmTp2lAnkNLmxXlFkOSNIwiT3qqyRZOh4DuxPOpfg9K+vtFmRdEJ
RwIDAQAB
-----END PUBLIC KEY-----''';
final int encryptionKeySize = 64;

enum AppNames {
  flexible,

  // For application with name 'autoConfirm' and with confirmationType = 'auto'
  // all the usernames are automatically confirmed.
  autoConfirm,

  emailConfirm,
}

const int maxInt = 9223372036854775807;
const int minInt = -9223372036854775808;
const int jsMaxInt = 9007199254740991;
const int jsMinInt = -9007199254740991;

//Overrides test method so we can filter tests
void test(String name, dynamic Function() testFunction, {dynamic skip}) {
  if (testName != null && !name.contains(testName!)) {
    return;
  }

  var timeout = 30;
  assert(() {
    timeout = Duration.secondsPerDay;
    return true;
  }());

  testing.test(name, testFunction, skip: skip, timeout: Timeout(Duration(seconds: timeout)));
}

void xtest(String? name, dynamic Function() testFunction) {
  testing.test(name, testFunction, skip: "Test is disabled");
}

Future<void> setupTests(List<String>? args) async {
  arguments = parseTestArguments(args);
  testName = arguments["name"];
  setUpAll(() async => await setupBaas());

  setUp(() {
    final path = generateRandomRealmPath();
    Configuration.defaultRealmPath = path;

    addTearDown(() async {
      final paths = HashSet<String>();
      paths.add(path);

      realmCore.clearCachedApps();

      while (_openRealms.isNotEmpty) {
        final realm = _openRealms.removeFirst();
        paths.add(realm.config.path);
        realm.close();
      }

      for (final path in paths) {
        await tryDeleteRealm(path);
      }
    });
  });

  await _printPlatformInfo();
}

Matcher throws<T>([String? message]) => throwsA(isA<T>().having((dynamic exception) => exception.message, 'message', contains(message ?? '')));

String generateRandomRealmPath() {
  final path = _path.join(Directory.systemTemp.createTempSync("realm_test_").path, "${generateRandomString(10)}.realm");
  return path;
}

final random = Random();
String generateRandomString(int len) {
  const _chars = 'abcdefghjklmnopqrstuvwxuz';
  return List.generate(len, (index) => _chars[random.nextInt(_chars.length)]).join();
}

Realm getRealm(Configuration config) {
  if (config is FlexibleSyncConfiguration) {
    config.sessionStopPolicy = SessionStopPolicy.immediately;
  }

  final realm = Realm(config);
  _openRealms.add(realm);
  return realm;
}

/// This is needed to make sure the frozen Realm gets forcefully closed by the
/// time the test ends.
Realm freezeRealm(Realm realm) {
  final frozen = realm.freeze();
  _openRealms.add(frozen);
  return frozen;
}

/// This is needed to make sure the frozen Realm gets forcefully closed by the
/// time the test ends.
RealmResults<T> freezeResults<T extends RealmObject>(RealmResults<T> results) {
  final frozen = results.freeze();
  _openRealms.add(frozen.realm);
  return frozen;
}

/// This is needed to make sure the frozen Realm gets forcefully closed by the
/// time the test ends.
RealmList<T> freezeList<T>(RealmList<T> list) {
  final frozen = list.freeze();
  _openRealms.add(frozen.realm);
  return frozen;
}

/// This is needed to make sure the frozen Realm gets forcefully closed by the
/// time the test ends.
T freezeObject<T extends RealmObject>(T object) {
  final frozen = object.freeze();
  _openRealms.add(frozen.realm);
  return frozen as T;
}

/// This is needed to make sure the frozen Realm gets forcefully closed by the
/// time the test ends.
dynamic freezeDynamic(dynamic object) {
  dynamic frozen = object.freeze();
  _openRealms.add(frozen.realm as Realm);
  return frozen;
}

Future<void> tryDeleteRealm(String path) async {
  //Skip on CI to speed it up. We are creating the realms in $TEMP anyways.
  if (Platform.environment.containsKey("REALM_CI")) {
    return;
  }

  for (var i = 0; i < 5; i++) {
    try {
      Realm.deleteRealm(path);
      await File('$path.lock').delete();
      return;
    } catch (e) {
      const duration = Duration(milliseconds: 100);
      print('Failed to delete realm at path $path. Trying again in ${duration.inMilliseconds}ms');
      await Future<void>.delayed(duration);
    }
  }

  // TODO: File deletions does not work after tests so don't fail for now https://github.com/realm/realm-dart/issues/751
  // throw Exception('Failed to delete realm at path $path. Did you forget to close it?');
}

Map<String, String?> parseTestArguments(List<String>? arguments) {
  Map<String, String?> testArgs = {};
  final parser = ArgParser()
    ..addOption("name")
    ..addOption(argBaasUrl)
    ..addOption(argBaasCluster)
    ..addOption(argBaasApiKey)
    ..addOption(argBaasPrivateApiKey)
    ..addOption(argBaasProjectId)
    ..addOption(argDifferentiator);

  final result = parser.parse(arguments ?? []);
  testArgs
    ..addArgument(result, "name")
    ..addArgument(result, argBaasUrl)
    ..addArgument(result, argBaasCluster)
    ..addArgument(result, argBaasApiKey)
    ..addArgument(result, argBaasPrivateApiKey)
    ..addArgument(result, argBaasProjectId)
    ..addArgument(result, argDifferentiator);

  return testArgs;
}

extension on Map<String, String?> {
  void addArgument(ArgResults parsedResult, String argName) {
    final value = parsedResult.wasParsed(argName) ? parsedResult[argName]?.toString() : Platform.environment[argName];
    if (value != null && value.isNotEmpty) {
      this[argName] = value;
    }
  }
}

BaasClient? _baasClient;
Future<void> setupBaas() async {
  final baasUrl = arguments[argBaasUrl];
  if (baasUrl == null) {
    return;
  }

  final cluster = arguments[argBaasCluster];
  final apiKey = arguments[argBaasApiKey];
  final privateApiKey = arguments[argBaasPrivateApiKey];
  final projectId = arguments[argBaasProjectId];
  final differentiator = arguments[argDifferentiator];

  final client = await (cluster == null
      ? BaasClient.docker(baasUrl, differentiator)
      : BaasClient.atlas(baasUrl, cluster, apiKey!, privateApiKey!, projectId!, differentiator));

  client.publicRSAKey = publicRSAKeyForJWTValidation;

  var apps = await client.getOrCreateApps();
  baasApps.addAll(apps);
  _baasClient = client;
}

@isTest
Future<void> baasTest(
  String name,
  FutureOr<void> Function(AppConfiguration appConfig) testFunction, {
  AppNames appName = AppNames.flexible,
  dynamic skip,
}) async {
  final uriVariable = arguments[argBaasUrl];
  final url = uriVariable != null ? Uri.tryParse(uriVariable) : null;

  if (skip == null) {
    skip = url == null ? "BAAS URL not present" : false;
  } else if (skip is bool) {
    if (url == null) skip = "BAAS URL not present";
  }

  test(name, () async {
    final config = await getAppConfig(appName: appName);
    await testFunction(config);
  }, skip: skip);
}

Future<AppConfiguration> getAppConfig({AppNames appName = AppNames.flexible}) async {
  final baasUrl = arguments[argBaasUrl];

  final app = baasApps[appName.name] ??
      baasApps.values.firstWhere((element) => element.name == BaasClient.defaultAppName, orElse: () => throw RealmError("No BAAS apps"));

  final temporaryDir = await Directory.systemTemp.createTemp('realm_test_');
  return AppConfiguration(
    app.clientAppId,
    baseUrl: Uri.parse(baasUrl!),
    baseFilePath: temporaryDir,
    maxConnectionTimeout: Duration(minutes: 10),
    defaultRequestTimeout: Duration(minutes: 7),
  );
}

Future<User> getIntegrationUser(App app) async {
  final email = 'realm_tests_do_autoverify_${generateRandomString(10)}@realm.io';
  final password = 'password';
  await app.emailPasswordAuthProvider.registerUser(email, password);

  return await loginWithRetry(app, Credentials.emailPassword(email, password));
}

Future<String> createServerApiKey(App app, String name, {bool enabled = true}) async {
  final baasApp = baasApps.values.firstWhere((ba) => ba.clientAppId == app.id);
  final client = _baasClient ?? (throw StateError("No BAAS client"));
  return await client.createApiKey(baasApp, name, enabled);
}

Future<Realm> getIntegrationRealm({App? app, ObjectId? differentiator}) async {
  app ??= App(await getAppConfig());
  final user = await getIntegrationUser(app);

  final config = Configuration.flexibleSync(user, [Task.schema, Schedule.schema, NullableTypes.schema]);
  final realm = getRealm(config);
  if (differentiator != null) {
    realm.subscriptions.update((mutableSubscriptions) {
      mutableSubscriptions.add(realm.query<NullableTypes>('differentiator = \$0', [differentiator]));
    });

    await realm.subscriptions.waitForSynchronization();
  }

  return realm;
}

Future<User> loginWithRetry(App app, Credentials credentials, {int retryCount = 3}) async {
  try {
    return await app.logIn(credentials);
  } catch (e) {
    if (retryCount > 1) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return await loginWithRetry(app, credentials, retryCount: retryCount - 1);
    }
    rethrow;
  }
}

Future<void> waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 1),
  Duration retryDelay = const Duration(milliseconds: 100),
  String? message,
}) async {
  await Future.any<void>([
    Future<void>.delayed(timeout, () => throw TimeoutException('Condition not met within $timeout. Message: ${message != null ? ': $message' : ''}')),
    Future.doWhile(() async {
      if (condition()) {
        return false;
      }
      await Future<void>.delayed(retryDelay);
      return true;
    })
  ]);
}

extension RealmObjectTest on RealmObject {
  String toJson() => realmCore.objectToString(this);
}

void clearCachedApps() => realmCore.clearCachedApps();

Future<void> _printPlatformInfo() async {
  final pointerSize = sizeOf<IntPtr>() * 8;
  final os = Platform.operatingSystem;
  String? cpu;

  if (!isFlutterPlatform) {
    if (Platform.isWindows) {
      cpu = Platform.environment['PROCESSOR_ARCHITECTURE'];
    } else {
      final info = await Process.run('uname', ['-m']);
      cpu = info.stdout.toString().replaceAll('\n', '');
    }
  }

  print('Current PID $pid; OS $os, $pointerSize bit, CPU ${cpu ?? 'unknown'}');
}
