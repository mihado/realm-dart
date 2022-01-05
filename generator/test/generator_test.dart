import 'package:build_test/build_test.dart';
import 'package:realm_generator/realm_generator.dart';
import 'package:test/test.dart';

void main() {
  test('pinhole', () async {
    await testBuilder(
      generateRealmObjects(),
      {
        'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class _Foo {
  int x = 0;
}''',
      },
      outputs: {
        'pkg|lib/src/test.realm_objects.g.part':
            '// **************************************************************************\n'
                '// RealmObjectGenerator\n'
                '// **************************************************************************\n'
                '\n'
                'class Foo extends _Foo with RealmObject {\n'
                '  static var _defaultsSet = false;\n'
                '\n'
                '  Foo({\n'
                '    int? x,\n'
                '  }) {\n'
                '    if (x != null) this.x = x;\n'
                '    _defaultsSet = _defaultsSet ||\n'
                '        RealmObject.setDefaults<Foo>({\n'
                '          \'x\': 0,\n'
                '        });\n'
                '  }\n'
                '\n'
                '  Foo._();\n'
                '\n'
                '  @override\n'
                '  int get x => RealmObject.get<int>(this, \'x\') as int;\n'
                '  @override\n'
                '  set x(int value) => RealmObject.set(this, \'x\', value);\n'
                '\n'
                '  static SchemaObject get schema => _schema ??= _initSchema();\n'
                '  static SchemaObject? _schema;\n'
                '  static SchemaObject _initSchema() {\n'
                '    RealmObject.registerFactory<Foo>(() => Foo._());\n'
                '    return const SchemaObject(Foo, [\n'
                '      SchemaProperty(\'x\', RealmPropertyType.int),\n'
                '    ]);\n'
                '  }\n'
                '}\n',
      },
      reader: await PackageAssetReader.currentIsolate(),
    );
  });

  test('all types', () async {
    await testBuilder(
      generateRealmObjects(),
      {
        'pkg|lib/src/test.dart': r'''
import 'dart:typed_data';

import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
@MapTo('Fooo')
class _Foo {
  int x = 0;
} 

@RealmModel()
class _Bar {
  @PrimaryKey()
  late final String id;
  late bool aBool, another;
  var data = Uint8List(16);
  late RealmAny any;
  @MapTo('tidspunkt')
  var timestamp = DateTime.now();
  var aDouble = 0.0;
  late Decimal128 decimal;
  _Foo? foo;
  late ObjectId id;
  late Uuid uuid;
  @Ignored()
  var theMeaningOfEverything = 42;
  final list = [0]; // list of ints with default value
  late final Set<int> set;
  final map = <String, int>{};

  @Indexed()
  String? anOptionalString;
}'''
      },
      reader: await PackageAssetReader.currentIsolate(),
    );
  });

  test('not a realm type', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

class NonRealm {}

@RealmModel()
class _Bad {
  late NonRealm notARealmType;
}'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(
        isA<RealmInvalidGenerationSourceError>().having(
          (e) => e.toString(),
          'toString()',
          'Not a realm type\n'
              '\n'
              'in: package:pkg/src/test.dart:9:8\n'
              '    ╷\n'
              '5   │   class NonRealm {}\n'
              '    │         ━━━━━━━━ \n'
              '... │\n'
              '7   │ ┌ @RealmModel()\n'
              '8   │ │ class _Bad {\n'
              '    │ └─── in realm model \'_Bad\'\n'
              '9   │     late NonRealm notARealmType;\n'
              '    │          ^^^^^^^^ NonRealm is not a realm type\n'
              '    ╵\n'
              'Add a @RealmModel annotation on \'NonRealm\', or an @Ignored annotation on \'notARealmType\'.\n',
        ),
      ),
    );
  });

  test('not an indexable type', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class _Bad {
  @Indexed()
  Uuid notAnIndexableType;
}'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(
        isA<RealmInvalidGenerationSourceError>().having(
          (e) => e.toString(),
          'toString()',
          'Realm only support indexes on String, int, and bool fields\n'
              '\n'
              'in: package:pkg/src/test.dart:8:3\n'
              '  ╷\n'
              '5 │ ┌ @RealmModel()\n'
              '6 │ │ class _Bad {\n'
              '  │ └─── in realm model \'_Bad\'\n'
              '7 │     @Indexed()\n'
              '  │     ━━━━━━━━━━ index is requested on \'notAnIndexableType\', but\n'
              '8 │     Uuid notAnIndexableType;\n'
              '  │     ^^^^ Uuid is not an indexable type\n'
              '  ╵\n'
              'Change the type of \'notAnIndexableType\', or remove the @Indexed() annotation\n',
        ),
      ),
    );
  });

  test('primary key cannot be nullable', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class _Bad {
  @PrimaryKey()
  int? nullableKeyNotAllowed;
}'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(
        isA<RealmInvalidGenerationSourceError>().having(
          (e) => e.toString(),
          'toString()',
          'Primary key cannot be nullable\n'
              '\n'
              'in: package:pkg/src/test.dart:8:3\n'
              '  ╷\n'
              '5 │ ┌ @RealmModel()\n'
              '6 │ │ class _Bad {\n'
              '  │ └─── in realm model \'_Bad\'\n'
              '7 │     @PrimaryKey()\n'
              '  │     ━━━━━━━━━━━━━ the primary key \'nullableKeyNotAllowed\' is\n'
              '8 │     int? nullableKeyNotAllowed;\n'
              '  │     ^^^^ nullable\n'
              '  ╵\n'
              'Consider using the @Indexed() annotation instead, or make \'nullableKeyNotAllowed\' an int.\n',
        ),
      ),
    );
  });

  test('primary key not final', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class _Bad {
  @PrimaryKey()
  late int primartKeyIsNotFinal;
}'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(
        isA<RealmInvalidGenerationSourceError>().having(
          (e) => e.toString(),
          'toString()',
          'Primary key field is not final\n'
              '\n'
              'in: package:pkg/src/test.dart:7:3\n'
              '  ╷\n'
              '7 │ ┌   @PrimaryKey()\n'
              '8 │ └   late int primartKeyIsNotFinal;\n'
              '  ╵\n'
              'Add a final keyword to the definition of \'primartKeyIsNotFinal\', or remove the @PrimaryKey annotation.\n',
        ),
      ),
    );
  });

  test('primary keys always indexed', () async {
    final sb = StringBuffer();
    var done = false;
    await testBuilder(
      generateRealmObjects(),
      {
        'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class _Questionable {
  @PrimaryKey()
  @Indexed()
  late final int primartKeysAreAlwaysIndexed;
}'''
      },
      reader: await PackageAssetReader.currentIsolate(),
      onLog: (l) {
        if (!done) {
          // disregard all, but first record
          sb.writeln(l);
          done = true;
        }
      },
    );
    expect(
      sb.toString(),
      '[INFO] testBuilder: Indexed is implied for a primary key\n'
      '\n'
      'in: package:pkg/src/test.dart:7:3\n'
      '  ╷\n'
      '7 │ ┌   @PrimaryKey()\n'
      '8 │ │   @Indexed()\n'
      '9 │ └   late final int primartKeysAreAlwaysIndexed;\n'
      '  ╵\n'
      'Remove either the @Indexed or @PrimaryKey annotation from \'primartKeysAreAlwaysIndexed\'.\n'
      '\n',
    );
  });

  test('list of list not supported', () async {
    await expectLater(
        () async => await testBuilder(
              generateRealmObjects(),
              {
                'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class _Bad {
  late int x;
  var listOfLists = [[0], [1]];
}

'''
              },
              reader: await PackageAssetReader.currentIsolate(),
            ),
        throwsA(isA<RealmInvalidGenerationSourceError>().having(
          (e) => e.toString(),
          'toString()',
          'Not a realm type\n'
              '\n'
              'in: package:pkg/src/test.dart:8:21\n'
              '    ╷\n'
              '5   │ ┌ @RealmModel()\n'
              '6   │ │ class _Bad {\n'
              '    │ └─── in realm model \'_Bad\'\n'
              '... │\n'
              '8   │     var listOfLists = [[0], [1]];\n'
              '    │                       ^^^^^^^^^^ List<List<int>> is not a realm type\n'
              '    ╵\n'
              'Add an @Ignored annotation on \'listOfLists\'.\n',
        )));
  });

  test('missing underscore', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class _Bad {
  late Other other;
}

@RealmModel()
class _Other {}

'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'Not a realm type\n'
            '\n'
            'in: package:pkg/src/test.dart:7:8\n'
            '  ╷\n'
            '5 │ ┌ @RealmModel()\n'
            '6 │ │ class _Bad {\n'
            '  │ └─── in realm model \'_Bad\'\n'
            '7 │     late Other other;\n'
            '  │          ^^^^^ Other is not a realm type\n'
            '  ╵\n'
            'Did you intend to use _Other as type for \'other\'?\n',
      )),
    );
  });

  test('double primary key', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class _Bad {
  @PrimaryKey()
  late final int first;

  @MapTo('third')
  @PrimaryKey()
  late final String second; // just a thought..
}
'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'Primary key already defined\n'
            '\n'
            'in: package:pkg/src/test.dart:11:3\n'
            '    ╷\n'
            '5   │ ┌ @RealmModel()\n'
            '6   │ │ class _Bad {\n'
            '    │ └─── in realm model \'_Bad\'\n'
            '7   │     @PrimaryKey()\n'
            '    │     ━━━━━━━━━━━━━ the @PrimaryKey() annotation is used\n'
            '8   │     late final int first;\n'
            '    │                    ━━━━━ on both \'first\', and\n'
            '... │\n'
            '11  │     @PrimaryKey()\n'
            '    │     ^^^^^^^^^^^^^ again\n'
            '12  │     late final String second; // just a thought..\n'
            '    │                       ━━━━━━ on \'second\'\n'
            '    ╵\n'
            'Remove @PrimaryKey() annotation from either \'second\' or \'first\'\n',
      )),
    );
  });

  test('invalid model name prefix', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class Bad { // missing _ or $ prefix
}
'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'Missing prefix on realm model name\n'
            '\n'
            'in: package:pkg/src/test.dart:6:7\n'
            '  ╷\n'
            '5 │ ┌ @RealmModel()\n'
            '6 │ │ class Bad { // missing _ or \$ prefix\n'
            '  │ │       ^^^ missing prefix\n'
            '  │ └─── on realm model \'Bad\'\n'
            '  ╵\n'
            'Either add a @MapTo annotation, or align class name to match prefix [_\$] (regular expression)\n',
      )),
    );
  });

  test('invalid model name mapping', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

const one = '1';
@RealmModel()
@MapTo(one) // <- invalid
// prefix is not important, as we explicitly define name with @MapTo, 
// but obviously 1 is not a valid class name
class Bad {}
'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'Invalid class name\n'
            '\n'
            'in: package:pkg/src/test.dart:7:8\n'
            '   ╷\n'
            '6  │ ┌ @RealmModel()\n'
            '7  │ │ @MapTo(one) // <- invalid\n'
            '   │ │        ^^^ which evaluates to \'1\' is not a valid class name\n'
            '8  │ │ // prefix is not important, as we explicitly define name with @MapTo, \n'
            '9  │ │ // but obviously 1 is not a valid class name\n'
            '10 │ │ class Bad {}\n'
            '   │ └─── when generating realm object class for \'Bad\'\n'
            '   ╵\n'
            'We need a valid indentifier\n',
      )),
    );
  });

  test('repeated class annotations', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
@RealmModel()
class _Bad {}
'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'Repeated annotation\n'
            '\n'
            'in: package:pkg/src/test.dart:6:1\n'
            '  ╷\n'
            '5 │ @RealmModel()\n'
            '  │ ━━━━━━━━━━━━━ 1st\n'
            '6 │ @RealmModel()\n'
            '  │ ^^^^^^^^^^^^^ 2nd\n'
            '7 │ class _Bad {}\n'
            '  │       ━━━━ on _Bad\n'
            '  ╵\n'
            'Remove all duplicated @RealmModel() annotations.\n',
      )),
    );
  });

  test('repeated field annotations', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class _Bad { 
  @PrimaryKey()
  @PrimaryKey()
  late final int id;
}
'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'Repeated annotation\n'
            '\n'
            'in: package:pkg/src/test.dart:8:3\n'
            '  ╷\n'
            '7 │   @PrimaryKey()\n'
            '  │   ━━━━━━━━━━━━━ 1st\n'
            '8 │   @PrimaryKey()\n'
            '  │   ^^^^^^^^^^^^^ 2nd\n'
            '9 │   late final int id;\n'
            '  │                  ━━ on id\n'
            '  ╵\n'
            'Remove all duplicated @PrimaryKey() annotations.\n',
      )),
    );
  });

  test('invalid extend', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

class Base {}

@RealmModel()
class _Bad extends Base { 
  @PrimaryKey()
  late final int id;
}
'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'Realm model classes can only extend Object\n'
            '\n'
            'in: package:pkg/src/test.dart:8:7\n'
            '  ╷\n'
            '7 │ ┌ @RealmModel()\n'
            '8 │ │ class _Bad extends Base { \n'
            '  │ │       ^^^^ cannot extend Base\n'
            '  │ └─── on realm model \'_Bad\'\n'
            '  ╵',
      )),
    );
  });

  test('illigal constructor', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class _Bad extends Base { 
  @PrimaryKey()
  late final int id;

  _Bad(this.id);
}
'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'No constructors allowed on realm model classes\n'
            '\n'
            'in: package:pkg/src/test.dart:10:3\n'
            '    ╷\n'
            '5   │ ┌ @RealmModel()\n'
            '6   │ │ class _Bad extends Base { \n'
            '    │ └─── on realm model \'_Bad\'\n'
            '... │\n'
            '10  │     _Bad(this.id);\n'
            '    │     ^ illegal constructor\n'
            '    ╵\n'
            'Remove constructor\n',
      )),
    );
  });

  test('non-final list', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class _Bad { 
  @PrimaryKey()
  late final int id;

  List<int> wrong;
}
'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'Realm collection field must be final\n'
            '\n'
            'in: package:pkg/src/test.dart:10:13\n'
            '    ╷\n'
            '5   │ ┌ @RealmModel()\n'
            '6   │ │ class _Bad { \n'
            '    │ └─── in realm model \'_Bad\'\n'
            '... │\n'
            '10  │     List<int> wrong;\n'
            '    │               ^^^^^ is not final\n'
            '    ╵\n'
            'Add a final keyword to the definition of \'wrong\'\n',
      )),
    );
  });

  test('nullable list', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class _Bad { 
  @PrimaryKey()
  late final int id;

  final List<int>? wrong;
}
'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'Realm collections cannot be nullable\n'
            '\n'
            'in: package:pkg/src/test.dart:10:9\n'
            '    ╷\n'
            '5   │ ┌ @RealmModel()\n'
            '6   │ │ class _Bad { \n'
            '    │ └─── in realm model \'_Bad\'\n'
            '... │\n'
            '10  │     final List<int>? wrong;\n'
            '    │           ^^^^^^^^^^ is nullable\n'
            '    ╵',
      )),
    );
  });

  test('nullable list elements', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class _Other {}

@RealmModel()
class _Bad { 
  @PrimaryKey()
  late final int id;

  final List<int?> okay;
  final List<_Other?> wrong;
}
'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'Nullable realm objects are not allowed in collections\n'
            '\n'
            'in: package:pkg/src/test.dart:14:9\n'
            '    ╷\n'
            '8   │ ┌ @RealmModel()\n'
            '9   │ │ class _Bad { \n'
            '    │ └─── in realm model \'_Bad\'\n'
            '... │\n'
            '14  │     final List<_Other?> wrong;\n'
            '    │           ^^^^^^^^^^^^^ which has a nullable realm object element type\n'
            '    ╵\n'
            'Ensure element type is non-nullable\n',
      )),
    );
  });

  test('non-nullable realm object reference', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class _Other {}

@RealmModel()
class _Bad { 
  @PrimaryKey()
  late final int id;

  late _Other wrong;
}
'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'Realm object references must be nullable\n'
            '\n'
            'in: package:pkg/src/test.dart:13:8\n'
            '    ╷\n'
            '8   │ ┌ @RealmModel()\n'
            '9   │ │ class _Bad { \n'
            '    │ └─── in realm model \'_Bad\'\n'
            '... │\n'
            '13  │     late _Other wrong;\n'
            '    │          ^^^^^^ is not nullable\n'
            '    ╵\n'
            'Change type to _Other?\n',
      )),
    );
  });

  test('defining both _Bad and \$Bad', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
class $Bad {}

@RealmModel()
class _Bad {}
'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'Mapping already defined\n'
            '\n'
            'in: package:pkg/src/test.dart:6:7\n'
            '    ╷\n'
            '5   │ ┌ @RealmModel()\n'
            '6   │ │ class \$Bad {}\n'
            '    │ │       ^^^^ \'_Bad\' already defines \'Bad\'\n'
            '    │ └─── \n'
            '... │\n'
            '8   │   @RealmModel()\n'
            '    │         ━━━━ here\n'
            '    ╵\n'
            'Avoid that \'\$Bad\' and \'_Bad\' both maps to \'Bad\'\n',
      )),
    );
  });

  test('defining both _Bad and \$Bad in different files', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test1.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test1.g.dart';

@RealmModel()
class $Bad2 {}
''',
          'pkg|lib/src/test2.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test2.g.dart';

@RealmModel()
class _Bad2 {}
''',
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'Mapping already defined\n'
            '\n'
            'in: package:pkg/src/test2.dart:6:7\n'
            '  ┌──> package:pkg/src/test2.dart\n'
            '5 │ ┌ @RealmModel()\n'
            '6 │ │ class _Bad2 {}\n'
            '  │ │       ^^^^^ \'\$Bad2\' already defines \'Bad2\'\n'
            '  │ └─── \n'
            '  ╵\n'
            '  ┌──> package:pkg/src/test1.dart\n'
            '6 │   class \$Bad2 {}\n'
            '  │         ━━━━━ here\n'
            '  ╵\n'
            'Avoid that \'_Bad2\' and \'\$Bad2\' both maps to \'Bad2\'\n',
      )),
    );
  });

  test('reusing mapTo name', () async {
    await expectLater(
      () async => await testBuilder(
        generateRealmObjects(),
        {
          'pkg|lib/src/test.dart': r'''
import 'package:realm_annotations/realm_annotations.dart';

part 'test.g.dart';

@RealmModel()
@MapTo('Bad3')
class _Foo {}

@MapTo('Bad3')
@RealmModel()
class _Bar {}
'''
        },
        reader: await PackageAssetReader.currentIsolate(),
      ),
      throwsA(isA<RealmInvalidGenerationSourceError>().having(
        (e) => e.toString(),
        'toString()',
        'Mapping already defined\n'
            '\n'
            'in: package:pkg/src/test.dart:11:7\n'
            '    ╷\n'
            '5   │ ┌ @RealmModel()\n'
            '6   │ │ @MapTo(\'Bad3\')\n'
            '7   │ │ class _Foo {}\n'
            '    │ └─── \n'
            '    │         ━━━━ here\n'
            '... │\n'
            '9   │ ┌ @MapTo(\'Bad3\')\n'
            '10  │ │ @RealmModel()\n'
            '11  │ │ class _Bar {}\n'
            '    │ │       ^^^^ \'_Foo\' already defines \'Bad3\'\n'
            '    │ └─── \n'
            '    ╵\n'
            'Avoid that \'_Bar\' and \'_Foo\' both maps to \'Bad3\'\n',
      )),
    );
  });
}
