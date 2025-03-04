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
import 'dart:ffi';
import 'dart:io';

import 'list.dart';
import 'native/realm_core.dart';
import 'realm_class.dart';

typedef DartDynamic = dynamic;

abstract class RealmAccessor {
  Object? get<T extends Object?>(RealmObject object, String name);
  void set(RealmObject object, String name, Object? value, {bool isDefault = false, bool update = false});

  static final Map<Type, Map<String, Object?>> _defaultValues = <Type, Map<String, Object?>>{};

  static void setDefaults<T extends RealmObject>(Map<String, Object?> values) {
    _defaultValues[T] = values;
  }

  static Object? getDefaultValue(Type realmObjectType, String name) {
    final type = realmObjectType;
    if (!_defaultValues.containsKey(type)) {
      throw RealmException("Type $type not found.");
    }

    final values = _defaultValues[type]!;
    if (values.containsKey(name)) {
      return values[name];
    }

    return null;
  }

  static Map<String, Object?>? getDefaults(Type realmObjectType) {
    if (!_defaultValues.containsKey(realmObjectType)) {
      return null;
    }

    return _defaultValues[realmObjectType]!;
  }
}

class RealmValuesAccessor implements RealmAccessor {
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  Object? get<T extends Object?>(RealmObject object, String name) {
    if (!_values.containsKey(name)) {
      return RealmAccessor.getDefaultValue(object.runtimeType, name);
    }

    return _values[name];
  }

  @override
  void set(RealmObject object, String name, Object? value, {bool isDefault = false, bool update = false}) {
    _values[name] = value;
  }

  void setAll(RealmObject object, RealmAccessor accessor, bool update) {
    final defaults = RealmAccessor.getDefaults(object.runtimeType);

    if (defaults != null) {
      for (var item in defaults.entries) {
        //check if a default value has been overwritten
        if (!_values.containsKey(item.key)) {
          accessor.set(object, item.key, item.value, isDefault: true);
        }
      }
    }

    for (var entry in _values.entries) {
      accessor.set(object, entry.key, entry.value, update: update);
    }
  }
}

class RealmObjectMetadata {
  final int classKey;
  final String name;
  final Type type;
  final String? primaryKey;

  final Map<String, RealmPropertyMetadata> _propertyKeys;

  String get _realmObjectTypeName => type == RealmObject ? name : type.toString();

  RealmObjectMetadata(this.name, this.type, this.primaryKey, this.classKey, this._propertyKeys);

  RealmPropertyMetadata operator [](String propertyName) =>
      _propertyKeys[propertyName] ?? (throw RealmException("Property $propertyName does not exist on class $_realmObjectTypeName"));

  String? getPropertyName(int propertyKey) {
    for (final entry in _propertyKeys.entries) {
      if (entry.value.key == propertyKey) {
        return entry.key;
      }
    }
    return null;
  }
}

class RealmPropertyMetadata {
  final int key;
  final RealmCollectionType collectionType;
  final RealmPropertyType propertyType;
  final bool isNullable;
  final String? objectType;
  final bool isPrimaryKey;
  const RealmPropertyMetadata(this.key, this.objectType, this.propertyType, this.isNullable, this.isPrimaryKey,
      [this.collectionType = RealmCollectionType.none]);
}

class RealmCoreAccessor implements RealmAccessor {
  final RealmObjectMetadata metadata;
  final bool isInMigration;

  RealmCoreAccessor(this.metadata, this.isInMigration);

  @override
  Object? get<T extends Object?>(RealmObject object, String name) {
    try {
      final propertyMeta = metadata[name];
      if (propertyMeta.collectionType == RealmCollectionType.list) {
        final handle = realmCore.getListProperty(object, propertyMeta.key);
        final listMetadata = propertyMeta.objectType == null ? null : object.realm.metadata.getByName(propertyMeta.objectType!);

        // listMetadata is not null when we have list of RealmObjects. If the API was
        // called with a generic object arg - get<Object> we construct a list of
        // RealmObjects since we don't know the type of the object.
        if (listMetadata != null && _isTypeGenericObject<T>()) {
          return object.realm.createList<RealmObject>(handle, listMetadata);
        }

        return object.realm.createList<T>(handle, listMetadata);
      }

      Object? value = realmCore.getProperty(object, propertyMeta.key);

      if (value is RealmObjectHandle) {
        final targetMetadata = propertyMeta.objectType != null ? object.realm.metadata.getByName(propertyMeta.objectType!) : object.realm.metadata.getByType(T);

        // If we have an object but the user called the API without providing a generic
        // arg, we construct a RealmObject since we don't know the type of the object.
        if (_isTypeGenericObject<T>()) {
          return object.realm.createObject(RealmObject, value, targetMetadata);
        }

        return object.realm.createObject(T, value, targetMetadata);
      }

      return value;
    } on Exception catch (e) {
      throw RealmException("Error getting property ${metadata._realmObjectTypeName}.$name Error: $e");
    }
  }

  @override
  void set(RealmObject object, String name, Object? value, {bool isDefault = false, bool update = false}) {
    final propertyMeta = metadata[name];
    try {
      if (value is RealmList<Object?>) {
        final handle = realmCore.getListProperty(object, propertyMeta.key);
        if (update) realmCore.listClear(handle);
        for (var i = 0; i < value.length; i++) {
          RealmListInternal.setValue(handle, object.realm, i, value[i], update: update);
        }
        return;
      }

      if (value is RealmObject && !value.isManaged) {
        object.realm.add(value, update: update);
      }

      if (propertyMeta.isPrimaryKey && !isInMigration) {
        final currentValue = realmCore.getProperty(object, propertyMeta.key);
        if (currentValue != value) {
          throw RealmException("Primary key cannot be changed (original value: '$currentValue', supplied value: '$value')");
        }
      }

      realmCore.setProperty(object, propertyMeta.key, value, isDefault);
    } on Exception catch (e) {
      throw RealmException("Error setting property ${metadata._realmObjectTypeName}.$name Error: $e");
    }
  }
}

mixin RealmEntity {
  Realm? _realm;

  /// The [Realm] instance this object belongs to.
  Realm get realm => _realm ?? (throw RealmStateError('$this not managed'));

  /// True if the object belongs to a [Realm].
  bool get isManaged => _realm != null;

  /// True if the entity belongs to a frozen [Realm].
  bool get isFrozen => _realm?.isFrozen == true;
}

extension RealmEntityInternal on RealmEntity {
  void setRealm(Realm value) => _realm = value;
}

/// An object that is persisted in `Realm`.
///
/// `RealmObjects` are generated from Realm data model classes marked with `@RealmModel` annotation and named with an underscore.
///
/// A data model class `_MyClass` will have a `RealmObject` generated with name `MyClass`.
///
/// [RealmObject] should not be used directly as it is part of the generated class hierarchy. ex: `MyClass extends _MyClass with RealmObject`.
/// {@category Realm}
mixin RealmObject on RealmEntity implements Finalizable {
  RealmObjectHandle? _handle;
  RealmAccessor _accessor = RealmValuesAccessor();
  static final Map<Type, RealmObject Function()> _factories = <Type, RealmObject Function()>{
    // Register default factories for `RealmObject` and `RealmObject?`. Whenever the user
    // asks for these types, we'll use the ConcreteRealmObject implementation.
    RealmObject: () => _ConcreteRealmObject(),
    _typeOf<RealmObject?>(): () => _ConcreteRealmObject(),
  };

  /// @nodoc
  static Object? get<T extends Object?>(RealmObject object, String name) {
    return object._accessor.get<T>(object, name);
  }

  /// @nodoc
  static void set<T extends Object>(RealmObject object, String name, T? value, {bool update = false}) {
    object._accessor.set(object, name, value, update: update);
  }

  /// @nodoc
  static void registerFactory<T extends RealmObject>(T Function() factory) {
    // We register a factory for both the type itself, but also the nullable
    // version of the type.
    _factories.putIfAbsent(T, () => factory);
    _factories.putIfAbsent(_typeOf<T?>(), () => factory);
  }

  /// @nodoc
  static T create<T extends RealmObject>() {
    if (!_factories.containsKey(T)) {
      throw RealmException("Factory for Realm object type $T not found");
    }
    return _factories[T]!() as T;
  }

  /// @nodoc
  static bool setDefaults<T extends RealmObject>(Map<String, Object> values) {
    RealmAccessor.setDefaults<T>(values);
    return true;
  }

  /// @nodoc
  static T freezeObject<T extends RealmObject>(T object) {
    if (!object.isManaged) {
      throw RealmStateError("Can't freeze unmanaged objects.");
    }

    if (!object.isValid) {
      throw RealmStateError("Can't freeze invalidated (deleted) objects.");
    }

    if (object.isFrozen) {
      return object;
    }

    final frozenRealm = object.realm.freeze();
    return frozenRealm.resolveObject(object)!;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RealmObject) return false;
    if (!isManaged || !other.isManaged) return false;
    return realmCore.objectEquals(this, other);
  }

  /// Gets a value indicating whether this object is managed and represents a row in the database.
  ///
  /// If a managed object has been removed from the [Realm], it is no longer valid and accessing properties on it
  /// will throw an exception.
  /// The Object is not valid if its [Realm] is closed or object is deleted.
  /// Unmanaged objects are always considered valid.
  bool get isValid => isManaged ? realmCore.objectIsValid(this) : true;

  /// Allows listening for property changes on this Realm object
  ///
  /// Returns a [Stream] of [RealmObjectChanges<T>] that can be listened to.
  ///
  /// If the object is not managed a [RealmStateError] is thrown.
  Stream<RealmObjectChanges<RealmObject>> get changes => throw RealmError("Invalid usage. Use the generated inheritors of RealmObject");

  /// @nodoc
  static Stream<RealmObjectChanges<T>> getChanges<T extends RealmObject>(T object) {
    if (!object.isManaged) {
      throw RealmStateError("Object is not managed");
    }

    if (object.isFrozen) {
      throw RealmStateError('Object is frozen and cannot emit changes.');
    }

    final controller = RealmObjectNotificationsController<T>(object);
    return controller.createStream();
  }

  // invocation.memberName in noSuchMethod is a Symbol, which hides its _name field. The idiomatic
  // way to obtain it is via Mirrors, which is not available in Flutter. Symbol.toString returns
  // Symbol("name"), so we use a simple regex to extract the symbol name. This is a bit fragile, but
  // is the approach used by the Flutter team as well: https://github.com/dart-lang/sdk/issues/28372.
  // If it turns out not to be reliable, we can instead construct symbols from the property names in
  // the Accessor metadata and compare symbols directly.
  static final RegExp _symbolRegex = RegExp('Symbol\\("(?<symbolName>.*?)=?"\\)');

  @override
  DartDynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      final name = _symbolRegex.firstMatch(invocation.memberName.toString())?.namedGroup("symbolName");
      if (name == null) {
        throw RealmError(
            "Could not find symbol name for ${invocation.memberName}. This is likely a bug in the Realm SDK - please file an issue at https://github.com/realm/realm-dart/issues");
      }

      return get(this, name);
    }

    if (invocation.isSetter) {
      final name = _symbolRegex.firstMatch(invocation.memberName.toString())?.namedGroup("symbolName");
      if (name == null) {
        throw RealmError(
            "Could not find symbol name for ${invocation.memberName}. This is likely a bug in the Realm SDK - please file an issue at https://github.com/realm/realm-dart/issues");
      }

      return set(this, name, invocation.positionalArguments.single);
    }

    return super.noSuchMethod(invocation);
  }

  /// An object exposing dynamic API for this [RealmObject] instance.
  late final DynamicRealmObject dynamic = DynamicRealmObject._(this);

  /// Creates a frozen snapshot of this [RealmObject].
  RealmObject freeze() => freezeObject(this);
}

/// @nodoc
//RealmObject package internal members
extension RealmObjectInternal on RealmObject {
  @pragma('vm:never-inline')
  void keepAlive() {
    _realm?.keepAlive();
    _handle?.keepAlive();
  }

  void manage(Realm realm, RealmObjectHandle handle, RealmCoreAccessor accessor, bool update) {
    if (_handle != null) {
      //most certainly a bug hence we throw an Error
      throw ArgumentError("Object is already managed");
    }

    _handle = handle;
    _realm = realm;

    if (_accessor is RealmValuesAccessor) {
      (_accessor as RealmValuesAccessor).setAll(this, accessor, update);
    }

    _accessor = accessor;
  }

  static RealmObject create(Type type, Realm realm, RealmObjectHandle handle, RealmCoreAccessor accessor) {
    if (!RealmObject._factories.containsKey(type)) {
      throw Exception("Factory for object type $type not found.");
    }

    final object = RealmObject._factories[type]!();
    object._handle = handle;
    object._accessor = accessor;
    object._realm = realm;
    return object;
  }

  RealmObjectHandle get handle {
    if (_handle?.released == true) {
      throw RealmClosedError('Cannot access an object that belongs to a closed Realm');
    }

    return _handle!;
  }

  RealmAccessor get accessor => _accessor;
}

/// An exception being thrown when a `Realm` operation or [RealmObject] access fails.
/// {@category Realm}
class RealmException implements Exception {
  final String message;

  RealmException(this.message);

  @override
  String toString() {
    return "RealmException: $message";
  }
}

/// An exception throws during execution of a user callback - e.g. during migration or initial data population.
/// {@category Realm}
class UserCallbackException extends RealmException {
  /// The error that was thrown while executing the callback.
  final Object userException;

  UserCallbackException(this.userException)
      : super('An exception occurred while executing a user-provided callback. See userException for more details: $userException');
}

/// Describes the changes in on a single RealmObject since the last time the notification callback was invoked.
class RealmObjectChanges<T extends RealmObject> implements Finalizable {
  // ignore: unused_field
  final RealmObjectChangesHandle _handle;

  /// The realm object being monitored for changes.
  final T object;

  /// `True` if the object was deleted.
  bool get isDeleted => realmCore.getObjectChangesIsDeleted(_handle);

  /// The property names that have changed.
  List<String> get properties {
    final propertyKeys = realmCore.getObjectChangesProperties(_handle);
    return object.realm.getPropertyNames(object.runtimeType, propertyKeys);
  }

  const RealmObjectChanges._(this._handle, this.object);
}

/// @nodoc
extension RealmObjectChangesInternal<T extends RealmObject> on RealmObjectChanges<T> {
  @pragma('vm:never-inline')
  void keepAlive() {
    _handle.keepAlive();
  }
}

/// @nodoc
class RealmObjectNotificationsController<T extends RealmObject> extends NotificationsController {
  T realmObject;
  late final StreamController<RealmObjectChanges<T>> streamController;

  RealmObjectNotificationsController(this.realmObject);

  @override
  RealmNotificationTokenHandle subscribe() {
    return realmCore.subscribeObjectNotifications(realmObject, this);
  }

  Stream<RealmObjectChanges<T>> createStream() {
    streamController = StreamController<RealmObjectChanges<T>>(onListen: start, onPause: stop, onResume: start, onCancel: stop);
    return streamController.stream;
  }

  @override
  void onChanges(HandleBase changesHandle) {
    if (changesHandle is! RealmObjectChangesHandle) {
      throw RealmError("Invalid changes handle. RealmObjectChangesHandle expected");
    }

    final changes = RealmObjectChanges<T>._(changesHandle, realmObject);
    streamController.add(changes);
  }

  @override
  void onError(RealmError error) {
    streamController.addError(error);
  }
}

/// @nodoc
class _ConcreteRealmObject with RealmEntity, RealmObject {}

// This is necessary whenever we need to pass T? as the type.
Type _typeOf<T>() => T;

bool _isTypeGenericObject<T>() => T == Object || T == _typeOf<Object?>();

/// Exposes a set of dynamic methods on the RealmObject type. These allow you to
/// access properties by name rather than via the strongly typed API.
///
/// {@category Realm}
class DynamicRealmObject {
  final RealmObject _obj;

  DynamicRealmObject._(this._obj);

  /// Gets a property by its name. If a generic type is specified, the property
  /// type will be validated against the type. Otherwise the result will be wrapped
  /// in [Object].
  T get<T extends Object?>(String name) {
    _validatePropertyType<T>(name, RealmCollectionType.none);
    return RealmObject.get<T>(_obj, name) as T;
  }

  /// Gets a list by the property name. If a generic type is specified, the property
  /// type will be validated against the type. Otherwise, a `List<Object>` will be
  /// returned.
  RealmList<T> getList<T extends Object?>(String name) {
    _validatePropertyType<T>(name, RealmCollectionType.list);
    return RealmObject.get<T>(_obj, name) as RealmList<T>;
  }

  RealmPropertyMetadata? _validatePropertyType<T extends Object?>(String name, RealmCollectionType expectedCollectionType) {
    final accessor = _obj.accessor;
    if (accessor is RealmCoreAccessor) {
      final prop = accessor.metadata._propertyKeys[name];
      if (prop == null) {
        throw RealmException("Property '$name' does not exist on class '${accessor.metadata.name}'");
      }

      if (prop.collectionType != expectedCollectionType) {
        throw RealmException(
            "Property '$name' on class '${accessor.metadata.name}' is '${prop.collectionType}' but the method used to access it expected '$expectedCollectionType'.");
      }

      // If the user passed in a type argument, we should validate its nullability; if they invoked
      // the method without a type arg, we don't
      if (T != _typeOf<Object?>() && prop.isNullable != null is T) {
        throw RealmException(
            "Property '$name' on class '${accessor.metadata.name}' is ${prop.isNullable ? 'nullable' : 'required'} but the generic argument passed to get<T> is $T.");
      }

      final targetType = _getPropertyType<T>();
      if (targetType != null && targetType != prop.propertyType) {
        throw RealmException(
            "Property '$name' on class '${accessor.metadata.name}' is not the correct type. Expected '$targetType', got '${prop.propertyType}'.");
      }

      return prop;
    }

    return null;
  }

  static final _propertyTypeMap = <Type, RealmPropertyType>{
    int: RealmPropertyType.int,
    _typeOf<int?>(): RealmPropertyType.int,
    double: RealmPropertyType.double,
    _typeOf<double?>(): RealmPropertyType.double,
    String: RealmPropertyType.string,
    _typeOf<String?>(): RealmPropertyType.string,
    bool: RealmPropertyType.bool,
    _typeOf<bool?>(): RealmPropertyType.bool,
    DateTime: RealmPropertyType.timestamp,
    _typeOf<DateTime?>(): RealmPropertyType.timestamp,
    ObjectId: RealmPropertyType.objectid,
    _typeOf<ObjectId?>(): RealmPropertyType.objectid,
    Uuid: RealmPropertyType.uuid,
    _typeOf<Uuid?>(): RealmPropertyType.uuid,
    RealmObject: RealmPropertyType.object,
    _typeOf<RealmObject?>(): RealmPropertyType.object,
  };

  RealmPropertyType? _getPropertyType<T extends Object?>() => _propertyTypeMap[T];
}
