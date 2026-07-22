// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ExercisesTable extends Exercises
    with TableInfo<$ExercisesTable, Exercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _muscleGroupMeta = const VerificationMeta(
    'muscleGroup',
  );
  @override
  late final GeneratedColumn<String> muscleGroup = GeneratedColumn<String>(
    'muscle_group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Other'),
  );
  static const VerificationMeta _equipmentMeta = const VerificationMeta(
    'equipment',
  );
  @override
  late final GeneratedColumn<String> equipment = GeneratedColumn<String>(
    'equipment',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Other'),
  );
  static const VerificationMeta _instructionsMeta = const VerificationMeta(
    'instructions',
  );
  @override
  late final GeneratedColumn<String> instructions = GeneratedColumn<String>(
    'instructions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _videoUrlMeta = const VerificationMeta(
    'videoUrl',
  );
  @override
  late final GeneratedColumn<String> videoUrl = GeneratedColumn<String>(
    'video_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    muscleGroup,
    equipment,
    instructions,
    videoUrl,
    isCustom,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<Exercise> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('muscle_group')) {
      context.handle(
        _muscleGroupMeta,
        muscleGroup.isAcceptableOrUnknown(
          data['muscle_group']!,
          _muscleGroupMeta,
        ),
      );
    }
    if (data.containsKey('equipment')) {
      context.handle(
        _equipmentMeta,
        equipment.isAcceptableOrUnknown(data['equipment']!, _equipmentMeta),
      );
    }
    if (data.containsKey('instructions')) {
      context.handle(
        _instructionsMeta,
        instructions.isAcceptableOrUnknown(
          data['instructions']!,
          _instructionsMeta,
        ),
      );
    }
    if (data.containsKey('video_url')) {
      context.handle(
        _videoUrlMeta,
        videoUrl.isAcceptableOrUnknown(data['video_url']!, _videoUrlMeta),
      );
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Exercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Exercise(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      muscleGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}muscle_group'],
      )!,
      equipment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipment'],
      )!,
      instructions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instructions'],
      )!,
      videoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_url'],
      ),
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }
}

class Exercise extends DataClass implements Insertable<Exercise> {
  final int id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String instructions;
  final String? videoUrl;
  final bool isCustom;
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.instructions,
    this.videoUrl,
    required this.isCustom,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['muscle_group'] = Variable<String>(muscleGroup);
    map['equipment'] = Variable<String>(equipment);
    map['instructions'] = Variable<String>(instructions);
    if (!nullToAbsent || videoUrl != null) {
      map['video_url'] = Variable<String>(videoUrl);
    }
    map['is_custom'] = Variable<bool>(isCustom);
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      name: Value(name),
      muscleGroup: Value(muscleGroup),
      equipment: Value(equipment),
      instructions: Value(instructions),
      videoUrl: videoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(videoUrl),
      isCustom: Value(isCustom),
    );
  }

  factory Exercise.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Exercise(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      muscleGroup: serializer.fromJson<String>(json['muscleGroup']),
      equipment: serializer.fromJson<String>(json['equipment']),
      instructions: serializer.fromJson<String>(json['instructions']),
      videoUrl: serializer.fromJson<String?>(json['videoUrl']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'muscleGroup': serializer.toJson<String>(muscleGroup),
      'equipment': serializer.toJson<String>(equipment),
      'instructions': serializer.toJson<String>(instructions),
      'videoUrl': serializer.toJson<String?>(videoUrl),
      'isCustom': serializer.toJson<bool>(isCustom),
    };
  }

  Exercise copyWith({
    int? id,
    String? name,
    String? muscleGroup,
    String? equipment,
    String? instructions,
    Value<String?> videoUrl = const Value.absent(),
    bool? isCustom,
  }) => Exercise(
    id: id ?? this.id,
    name: name ?? this.name,
    muscleGroup: muscleGroup ?? this.muscleGroup,
    equipment: equipment ?? this.equipment,
    instructions: instructions ?? this.instructions,
    videoUrl: videoUrl.present ? videoUrl.value : this.videoUrl,
    isCustom: isCustom ?? this.isCustom,
  );
  Exercise copyWithCompanion(ExercisesCompanion data) {
    return Exercise(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      muscleGroup: data.muscleGroup.present
          ? data.muscleGroup.value
          : this.muscleGroup,
      equipment: data.equipment.present ? data.equipment.value : this.equipment,
      instructions: data.instructions.present
          ? data.instructions.value
          : this.instructions,
      videoUrl: data.videoUrl.present ? data.videoUrl.value : this.videoUrl,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Exercise(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('muscleGroup: $muscleGroup, ')
          ..write('equipment: $equipment, ')
          ..write('instructions: $instructions, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('isCustom: $isCustom')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    muscleGroup,
    equipment,
    instructions,
    videoUrl,
    isCustom,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exercise &&
          other.id == this.id &&
          other.name == this.name &&
          other.muscleGroup == this.muscleGroup &&
          other.equipment == this.equipment &&
          other.instructions == this.instructions &&
          other.videoUrl == this.videoUrl &&
          other.isCustom == this.isCustom);
}

class ExercisesCompanion extends UpdateCompanion<Exercise> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> muscleGroup;
  final Value<String> equipment;
  final Value<String> instructions;
  final Value<String?> videoUrl;
  final Value<bool> isCustom;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.muscleGroup = const Value.absent(),
    this.equipment = const Value.absent(),
    this.instructions = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.isCustom = const Value.absent(),
  });
  ExercisesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.muscleGroup = const Value.absent(),
    this.equipment = const Value.absent(),
    this.instructions = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.isCustom = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Exercise> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? muscleGroup,
    Expression<String>? equipment,
    Expression<String>? instructions,
    Expression<String>? videoUrl,
    Expression<bool>? isCustom,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (muscleGroup != null) 'muscle_group': muscleGroup,
      if (equipment != null) 'equipment': equipment,
      if (instructions != null) 'instructions': instructions,
      if (videoUrl != null) 'video_url': videoUrl,
      if (isCustom != null) 'is_custom': isCustom,
    });
  }

  ExercisesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? muscleGroup,
    Value<String>? equipment,
    Value<String>? instructions,
    Value<String?>? videoUrl,
    Value<bool>? isCustom,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      instructions: instructions ?? this.instructions,
      videoUrl: videoUrl ?? this.videoUrl,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (muscleGroup.present) {
      map['muscle_group'] = Variable<String>(muscleGroup.value);
    }
    if (equipment.present) {
      map['equipment'] = Variable<String>(equipment.value);
    }
    if (instructions.present) {
      map['instructions'] = Variable<String>(instructions.value);
    }
    if (videoUrl.present) {
      map['video_url'] = Variable<String>(videoUrl.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('muscleGroup: $muscleGroup, ')
          ..write('equipment: $equipment, ')
          ..write('instructions: $instructions, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('isCustom: $isCustom')
          ..write(')'))
        .toString();
  }
}

class $RoutinesTable extends Routines with TableInfo<$RoutinesTable, Routine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('FF6A3D'),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _restSecondsMeta = const VerificationMeta(
    'restSeconds',
  );
  @override
  late final GeneratedColumn<int> restSeconds = GeneratedColumn<int>(
    'rest_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(90),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorHex,
    position,
    restSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routines';
  @override
  VerificationContext validateIntegrity(
    Insertable<Routine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('rest_seconds')) {
      context.handle(
        _restSecondsMeta,
        restSeconds.isAcceptableOrUnknown(
          data['rest_seconds']!,
          _restSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Routine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Routine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      restSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_seconds'],
      )!,
    );
  }

  @override
  $RoutinesTable createAlias(String alias) {
    return $RoutinesTable(attachedDatabase, alias);
  }
}

class Routine extends DataClass implements Insertable<Routine> {
  final int id;
  final String name;
  final String colorHex;
  final int position;

  /// Default rest between sets for this routine, in seconds.
  final int restSeconds;
  const Routine({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.position,
    required this.restSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color_hex'] = Variable<String>(colorHex);
    map['position'] = Variable<int>(position);
    map['rest_seconds'] = Variable<int>(restSeconds);
    return map;
  }

  RoutinesCompanion toCompanion(bool nullToAbsent) {
    return RoutinesCompanion(
      id: Value(id),
      name: Value(name),
      colorHex: Value(colorHex),
      position: Value(position),
      restSeconds: Value(restSeconds),
    );
  }

  factory Routine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Routine(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      position: serializer.fromJson<int>(json['position']),
      restSeconds: serializer.fromJson<int>(json['restSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'colorHex': serializer.toJson<String>(colorHex),
      'position': serializer.toJson<int>(position),
      'restSeconds': serializer.toJson<int>(restSeconds),
    };
  }

  Routine copyWith({
    int? id,
    String? name,
    String? colorHex,
    int? position,
    int? restSeconds,
  }) => Routine(
    id: id ?? this.id,
    name: name ?? this.name,
    colorHex: colorHex ?? this.colorHex,
    position: position ?? this.position,
    restSeconds: restSeconds ?? this.restSeconds,
  );
  Routine copyWithCompanion(RoutinesCompanion data) {
    return Routine(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      position: data.position.present ? data.position.value : this.position,
      restSeconds: data.restSeconds.present
          ? data.restSeconds.value
          : this.restSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Routine(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('position: $position, ')
          ..write('restSeconds: $restSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorHex, position, restSeconds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Routine &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorHex == this.colorHex &&
          other.position == this.position &&
          other.restSeconds == this.restSeconds);
}

class RoutinesCompanion extends UpdateCompanion<Routine> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> colorHex;
  final Value<int> position;
  final Value<int> restSeconds;
  const RoutinesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.position = const Value.absent(),
    this.restSeconds = const Value.absent(),
  });
  RoutinesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.colorHex = const Value.absent(),
    this.position = const Value.absent(),
    this.restSeconds = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Routine> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? colorHex,
    Expression<int>? position,
    Expression<int>? restSeconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorHex != null) 'color_hex': colorHex,
      if (position != null) 'position': position,
      if (restSeconds != null) 'rest_seconds': restSeconds,
    });
  }

  RoutinesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? colorHex,
    Value<int>? position,
    Value<int>? restSeconds,
  }) {
    return RoutinesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      position: position ?? this.position,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (restSeconds.present) {
      map['rest_seconds'] = Variable<int>(restSeconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutinesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('position: $position, ')
          ..write('restSeconds: $restSeconds')
          ..write(')'))
        .toString();
  }
}

class $WorkoutsTable extends Workouts with TableInfo<$WorkoutsTable, Workout> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<int> routineId = GeneratedColumn<int>(
    'routine_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES routines (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, routineId, name, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workouts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Workout> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_routineIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Workout map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Workout(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}routine_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $WorkoutsTable createAlias(String alias) {
    return $WorkoutsTable(attachedDatabase, alias);
  }
}

class Workout extends DataClass implements Insertable<Workout> {
  final int id;
  final int routineId;
  final String name;
  final int position;
  const Workout({
    required this.id,
    required this.routineId,
    required this.name,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['routine_id'] = Variable<int>(routineId);
    map['name'] = Variable<String>(name);
    map['position'] = Variable<int>(position);
    return map;
  }

  WorkoutsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutsCompanion(
      id: Value(id),
      routineId: Value(routineId),
      name: Value(name),
      position: Value(position),
    );
  }

  factory Workout.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Workout(
      id: serializer.fromJson<int>(json['id']),
      routineId: serializer.fromJson<int>(json['routineId']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'routineId': serializer.toJson<int>(routineId),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<int>(position),
    };
  }

  Workout copyWith({int? id, int? routineId, String? name, int? position}) =>
      Workout(
        id: id ?? this.id,
        routineId: routineId ?? this.routineId,
        name: name ?? this.name,
        position: position ?? this.position,
      );
  Workout copyWithCompanion(WorkoutsCompanion data) {
    return Workout(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Workout(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('name: $name, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, routineId, name, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workout &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.name == this.name &&
          other.position == this.position);
}

class WorkoutsCompanion extends UpdateCompanion<Workout> {
  final Value<int> id;
  final Value<int> routineId;
  final Value<String> name;
  final Value<int> position;
  const WorkoutsCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
  });
  WorkoutsCompanion.insert({
    this.id = const Value.absent(),
    required int routineId,
    required String name,
    this.position = const Value.absent(),
  }) : routineId = Value(routineId),
       name = Value(name);
  static Insertable<Workout> custom({
    Expression<int>? id,
    Expression<int>? routineId,
    Expression<String>? name,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
    });
  }

  WorkoutsCompanion copyWith({
    Value<int>? id,
    Value<int>? routineId,
    Value<String>? name,
    Value<int>? position,
  }) {
    return WorkoutsCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      name: name ?? this.name,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<int>(routineId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutsCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('name: $name, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

class $WorkoutItemsTable extends WorkoutItems
    with TableInfo<$WorkoutItemsTable, WorkoutItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _workoutIdMeta = const VerificationMeta(
    'workoutId',
  );
  @override
  late final GeneratedColumn<int> workoutId = GeneratedColumn<int>(
    'workout_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workouts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES exercises (id)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _targetSetsMeta = const VerificationMeta(
    'targetSets',
  );
  @override
  late final GeneratedColumn<int> targetSets = GeneratedColumn<int>(
    'target_sets',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _repsMinMeta = const VerificationMeta(
    'repsMin',
  );
  @override
  late final GeneratedColumn<int> repsMin = GeneratedColumn<int>(
    'reps_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(8),
  );
  static const VerificationMeta _repsMaxMeta = const VerificationMeta(
    'repsMax',
  );
  @override
  late final GeneratedColumn<int> repsMax = GeneratedColumn<int>(
    'reps_max',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toFailureMeta = const VerificationMeta(
    'toFailure',
  );
  @override
  late final GeneratedColumn<bool> toFailure = GeneratedColumn<bool>(
    'to_failure',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("to_failure" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _restSecondsMeta = const VerificationMeta(
    'restSeconds',
  );
  @override
  late final GeneratedColumn<int> restSeconds = GeneratedColumn<int>(
    'rest_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _suggestedWeightMeta = const VerificationMeta(
    'suggestedWeight',
  );
  @override
  late final GeneratedColumn<double> suggestedWeight = GeneratedColumn<double>(
    'suggested_weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ProgressionMode, String>
  progression = GeneratedColumn<String>(
    'progression',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('weight'),
  ).withConverter<ProgressionMode>($WorkoutItemsTable.$converterprogression);
  static const VerificationMeta _holdSecondsMeta = const VerificationMeta(
    'holdSeconds',
  );
  @override
  late final GeneratedColumn<int> holdSeconds = GeneratedColumn<int>(
    'hold_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(30),
  );
  static const VerificationMeta _incrementMeta = const VerificationMeta(
    'increment',
  );
  @override
  late final GeneratedColumn<double> increment = GeneratedColumn<double>(
    'increment',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.5),
  );
  static const VerificationMeta _successThresholdMeta = const VerificationMeta(
    'successThreshold',
  );
  @override
  late final GeneratedColumn<int> successThreshold = GeneratedColumn<int>(
    'success_threshold',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(defaultSuccessThreshold),
  );
  static const VerificationMeta _deloadMeta = const VerificationMeta('deload');
  @override
  late final GeneratedColumn<double> deload = GeneratedColumn<double>(
    'deload',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _failureThresholdMeta = const VerificationMeta(
    'failureThreshold',
  );
  @override
  late final GeneratedColumn<int> failureThreshold = GeneratedColumn<int>(
    'failure_threshold',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(defaultFailureThreshold),
  );
  static const VerificationMeta _successStreakMeta = const VerificationMeta(
    'successStreak',
  );
  @override
  late final GeneratedColumn<int> successStreak = GeneratedColumn<int>(
    'success_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _failStreakMeta = const VerificationMeta(
    'failStreak',
  );
  @override
  late final GeneratedColumn<int> failStreak = GeneratedColumn<int>(
    'fail_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workoutId,
    exerciseId,
    position,
    targetSets,
    repsMin,
    repsMax,
    toFailure,
    restSeconds,
    suggestedWeight,
    progression,
    holdSeconds,
    increment,
    successThreshold,
    deload,
    failureThreshold,
    successStreak,
    failStreak,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('workout_id')) {
      context.handle(
        _workoutIdMeta,
        workoutId.isAcceptableOrUnknown(data['workout_id']!, _workoutIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workoutIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('target_sets')) {
      context.handle(
        _targetSetsMeta,
        targetSets.isAcceptableOrUnknown(data['target_sets']!, _targetSetsMeta),
      );
    }
    if (data.containsKey('reps_min')) {
      context.handle(
        _repsMinMeta,
        repsMin.isAcceptableOrUnknown(data['reps_min']!, _repsMinMeta),
      );
    }
    if (data.containsKey('reps_max')) {
      context.handle(
        _repsMaxMeta,
        repsMax.isAcceptableOrUnknown(data['reps_max']!, _repsMaxMeta),
      );
    }
    if (data.containsKey('to_failure')) {
      context.handle(
        _toFailureMeta,
        toFailure.isAcceptableOrUnknown(data['to_failure']!, _toFailureMeta),
      );
    }
    if (data.containsKey('rest_seconds')) {
      context.handle(
        _restSecondsMeta,
        restSeconds.isAcceptableOrUnknown(
          data['rest_seconds']!,
          _restSecondsMeta,
        ),
      );
    }
    if (data.containsKey('suggested_weight')) {
      context.handle(
        _suggestedWeightMeta,
        suggestedWeight.isAcceptableOrUnknown(
          data['suggested_weight']!,
          _suggestedWeightMeta,
        ),
      );
    }
    if (data.containsKey('hold_seconds')) {
      context.handle(
        _holdSecondsMeta,
        holdSeconds.isAcceptableOrUnknown(
          data['hold_seconds']!,
          _holdSecondsMeta,
        ),
      );
    }
    if (data.containsKey('increment')) {
      context.handle(
        _incrementMeta,
        increment.isAcceptableOrUnknown(data['increment']!, _incrementMeta),
      );
    }
    if (data.containsKey('success_threshold')) {
      context.handle(
        _successThresholdMeta,
        successThreshold.isAcceptableOrUnknown(
          data['success_threshold']!,
          _successThresholdMeta,
        ),
      );
    }
    if (data.containsKey('deload')) {
      context.handle(
        _deloadMeta,
        deload.isAcceptableOrUnknown(data['deload']!, _deloadMeta),
      );
    }
    if (data.containsKey('failure_threshold')) {
      context.handle(
        _failureThresholdMeta,
        failureThreshold.isAcceptableOrUnknown(
          data['failure_threshold']!,
          _failureThresholdMeta,
        ),
      );
    }
    if (data.containsKey('success_streak')) {
      context.handle(
        _successStreakMeta,
        successStreak.isAcceptableOrUnknown(
          data['success_streak']!,
          _successStreakMeta,
        ),
      );
    }
    if (data.containsKey('fail_streak')) {
      context.handle(
        _failStreakMeta,
        failStreak.isAcceptableOrUnknown(data['fail_streak']!, _failStreakMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      workoutId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}workout_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exercise_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      targetSets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_sets'],
      )!,
      repsMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps_min'],
      )!,
      repsMax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps_max'],
      ),
      toFailure: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}to_failure'],
      )!,
      restSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_seconds'],
      ),
      suggestedWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}suggested_weight'],
      ),
      progression: $WorkoutItemsTable.$converterprogression.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}progression'],
        )!,
      ),
      holdSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hold_seconds'],
      )!,
      increment: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}increment'],
      )!,
      successThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}success_threshold'],
      )!,
      deload: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}deload'],
      )!,
      failureThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failure_threshold'],
      )!,
      successStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}success_streak'],
      )!,
      failStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fail_streak'],
      )!,
    );
  }

  @override
  $WorkoutItemsTable createAlias(String alias) {
    return $WorkoutItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ProgressionMode, String, String>
  $converterprogression = const EnumNameConverter<ProgressionMode>(
    ProgressionMode.values,
  );
}

class WorkoutItem extends DataClass implements Insertable<WorkoutItem> {
  final int id;
  final int workoutId;
  final int exerciseId;
  final int position;
  final int targetSets;

  /// Low end of the rep target (also the value used for a fixed count).
  final int repsMin;

  /// High end of the rep range. Null means a fixed count of [repsMin].
  final int? repsMax;

  /// When true, the set is taken to failure ([repsMin] is the goal to beat).
  final bool toFailure;

  /// Per-exercise rest override, in seconds. Null falls back to the routine.
  final int? restSeconds;
  final double? suggestedWeight;

  /// The axis this slot advances along — see [ProgressionMode].
  final ProgressionMode progression;

  /// The per-set hold, in seconds, when [progression] is
  /// [ProgressionMode.time]. Ignored by the other modes, which count reps.
  final int holdSeconds;

  /// How far the target moves on a step up, in the mode's own unit: kilograms,
  /// reps or seconds. Kept as a real because 2.5 kg is the smallest plate pair
  /// most gyms own.
  final double increment;

  /// Consecutive clean sessions needed before the target goes up.
  final int successThreshold;

  /// How far the target drops on a back-off, in the mode's own unit.
  final double deload;

  /// Consecutive missed sessions before the target backs off.
  final int failureThreshold;

  /// Clean sessions since the last step up or miss.
  ///
  /// Stored rather than derived from history, unlike the next-workout
  /// suggestion: the target itself moves, so a session's success can only be
  /// judged against the goal that was live *on the day*, and replaying that
  /// from logged sets would have to reconstruct every intervening edit. The
  /// counters ride along with the thing they are counting towards instead.
  final int successStreak;

  /// Missed sessions since the last back-off or clean session.
  final int failStreak;
  const WorkoutItem({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.position,
    required this.targetSets,
    required this.repsMin,
    this.repsMax,
    required this.toFailure,
    this.restSeconds,
    this.suggestedWeight,
    required this.progression,
    required this.holdSeconds,
    required this.increment,
    required this.successThreshold,
    required this.deload,
    required this.failureThreshold,
    required this.successStreak,
    required this.failStreak,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['workout_id'] = Variable<int>(workoutId);
    map['exercise_id'] = Variable<int>(exerciseId);
    map['position'] = Variable<int>(position);
    map['target_sets'] = Variable<int>(targetSets);
    map['reps_min'] = Variable<int>(repsMin);
    if (!nullToAbsent || repsMax != null) {
      map['reps_max'] = Variable<int>(repsMax);
    }
    map['to_failure'] = Variable<bool>(toFailure);
    if (!nullToAbsent || restSeconds != null) {
      map['rest_seconds'] = Variable<int>(restSeconds);
    }
    if (!nullToAbsent || suggestedWeight != null) {
      map['suggested_weight'] = Variable<double>(suggestedWeight);
    }
    {
      map['progression'] = Variable<String>(
        $WorkoutItemsTable.$converterprogression.toSql(progression),
      );
    }
    map['hold_seconds'] = Variable<int>(holdSeconds);
    map['increment'] = Variable<double>(increment);
    map['success_threshold'] = Variable<int>(successThreshold);
    map['deload'] = Variable<double>(deload);
    map['failure_threshold'] = Variable<int>(failureThreshold);
    map['success_streak'] = Variable<int>(successStreak);
    map['fail_streak'] = Variable<int>(failStreak);
    return map;
  }

  WorkoutItemsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutItemsCompanion(
      id: Value(id),
      workoutId: Value(workoutId),
      exerciseId: Value(exerciseId),
      position: Value(position),
      targetSets: Value(targetSets),
      repsMin: Value(repsMin),
      repsMax: repsMax == null && nullToAbsent
          ? const Value.absent()
          : Value(repsMax),
      toFailure: Value(toFailure),
      restSeconds: restSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(restSeconds),
      suggestedWeight: suggestedWeight == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedWeight),
      progression: Value(progression),
      holdSeconds: Value(holdSeconds),
      increment: Value(increment),
      successThreshold: Value(successThreshold),
      deload: Value(deload),
      failureThreshold: Value(failureThreshold),
      successStreak: Value(successStreak),
      failStreak: Value(failStreak),
    );
  }

  factory WorkoutItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutItem(
      id: serializer.fromJson<int>(json['id']),
      workoutId: serializer.fromJson<int>(json['workoutId']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      position: serializer.fromJson<int>(json['position']),
      targetSets: serializer.fromJson<int>(json['targetSets']),
      repsMin: serializer.fromJson<int>(json['repsMin']),
      repsMax: serializer.fromJson<int?>(json['repsMax']),
      toFailure: serializer.fromJson<bool>(json['toFailure']),
      restSeconds: serializer.fromJson<int?>(json['restSeconds']),
      suggestedWeight: serializer.fromJson<double?>(json['suggestedWeight']),
      progression: $WorkoutItemsTable.$converterprogression.fromJson(
        serializer.fromJson<String>(json['progression']),
      ),
      holdSeconds: serializer.fromJson<int>(json['holdSeconds']),
      increment: serializer.fromJson<double>(json['increment']),
      successThreshold: serializer.fromJson<int>(json['successThreshold']),
      deload: serializer.fromJson<double>(json['deload']),
      failureThreshold: serializer.fromJson<int>(json['failureThreshold']),
      successStreak: serializer.fromJson<int>(json['successStreak']),
      failStreak: serializer.fromJson<int>(json['failStreak']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'workoutId': serializer.toJson<int>(workoutId),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'position': serializer.toJson<int>(position),
      'targetSets': serializer.toJson<int>(targetSets),
      'repsMin': serializer.toJson<int>(repsMin),
      'repsMax': serializer.toJson<int?>(repsMax),
      'toFailure': serializer.toJson<bool>(toFailure),
      'restSeconds': serializer.toJson<int?>(restSeconds),
      'suggestedWeight': serializer.toJson<double?>(suggestedWeight),
      'progression': serializer.toJson<String>(
        $WorkoutItemsTable.$converterprogression.toJson(progression),
      ),
      'holdSeconds': serializer.toJson<int>(holdSeconds),
      'increment': serializer.toJson<double>(increment),
      'successThreshold': serializer.toJson<int>(successThreshold),
      'deload': serializer.toJson<double>(deload),
      'failureThreshold': serializer.toJson<int>(failureThreshold),
      'successStreak': serializer.toJson<int>(successStreak),
      'failStreak': serializer.toJson<int>(failStreak),
    };
  }

  WorkoutItem copyWith({
    int? id,
    int? workoutId,
    int? exerciseId,
    int? position,
    int? targetSets,
    int? repsMin,
    Value<int?> repsMax = const Value.absent(),
    bool? toFailure,
    Value<int?> restSeconds = const Value.absent(),
    Value<double?> suggestedWeight = const Value.absent(),
    ProgressionMode? progression,
    int? holdSeconds,
    double? increment,
    int? successThreshold,
    double? deload,
    int? failureThreshold,
    int? successStreak,
    int? failStreak,
  }) => WorkoutItem(
    id: id ?? this.id,
    workoutId: workoutId ?? this.workoutId,
    exerciseId: exerciseId ?? this.exerciseId,
    position: position ?? this.position,
    targetSets: targetSets ?? this.targetSets,
    repsMin: repsMin ?? this.repsMin,
    repsMax: repsMax.present ? repsMax.value : this.repsMax,
    toFailure: toFailure ?? this.toFailure,
    restSeconds: restSeconds.present ? restSeconds.value : this.restSeconds,
    suggestedWeight: suggestedWeight.present
        ? suggestedWeight.value
        : this.suggestedWeight,
    progression: progression ?? this.progression,
    holdSeconds: holdSeconds ?? this.holdSeconds,
    increment: increment ?? this.increment,
    successThreshold: successThreshold ?? this.successThreshold,
    deload: deload ?? this.deload,
    failureThreshold: failureThreshold ?? this.failureThreshold,
    successStreak: successStreak ?? this.successStreak,
    failStreak: failStreak ?? this.failStreak,
  );
  WorkoutItem copyWithCompanion(WorkoutItemsCompanion data) {
    return WorkoutItem(
      id: data.id.present ? data.id.value : this.id,
      workoutId: data.workoutId.present ? data.workoutId.value : this.workoutId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      position: data.position.present ? data.position.value : this.position,
      targetSets: data.targetSets.present
          ? data.targetSets.value
          : this.targetSets,
      repsMin: data.repsMin.present ? data.repsMin.value : this.repsMin,
      repsMax: data.repsMax.present ? data.repsMax.value : this.repsMax,
      toFailure: data.toFailure.present ? data.toFailure.value : this.toFailure,
      restSeconds: data.restSeconds.present
          ? data.restSeconds.value
          : this.restSeconds,
      suggestedWeight: data.suggestedWeight.present
          ? data.suggestedWeight.value
          : this.suggestedWeight,
      progression: data.progression.present
          ? data.progression.value
          : this.progression,
      holdSeconds: data.holdSeconds.present
          ? data.holdSeconds.value
          : this.holdSeconds,
      increment: data.increment.present ? data.increment.value : this.increment,
      successThreshold: data.successThreshold.present
          ? data.successThreshold.value
          : this.successThreshold,
      deload: data.deload.present ? data.deload.value : this.deload,
      failureThreshold: data.failureThreshold.present
          ? data.failureThreshold.value
          : this.failureThreshold,
      successStreak: data.successStreak.present
          ? data.successStreak.value
          : this.successStreak,
      failStreak: data.failStreak.present
          ? data.failStreak.value
          : this.failStreak,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutItem(')
          ..write('id: $id, ')
          ..write('workoutId: $workoutId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('position: $position, ')
          ..write('targetSets: $targetSets, ')
          ..write('repsMin: $repsMin, ')
          ..write('repsMax: $repsMax, ')
          ..write('toFailure: $toFailure, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('suggestedWeight: $suggestedWeight, ')
          ..write('progression: $progression, ')
          ..write('holdSeconds: $holdSeconds, ')
          ..write('increment: $increment, ')
          ..write('successThreshold: $successThreshold, ')
          ..write('deload: $deload, ')
          ..write('failureThreshold: $failureThreshold, ')
          ..write('successStreak: $successStreak, ')
          ..write('failStreak: $failStreak')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workoutId,
    exerciseId,
    position,
    targetSets,
    repsMin,
    repsMax,
    toFailure,
    restSeconds,
    suggestedWeight,
    progression,
    holdSeconds,
    increment,
    successThreshold,
    deload,
    failureThreshold,
    successStreak,
    failStreak,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutItem &&
          other.id == this.id &&
          other.workoutId == this.workoutId &&
          other.exerciseId == this.exerciseId &&
          other.position == this.position &&
          other.targetSets == this.targetSets &&
          other.repsMin == this.repsMin &&
          other.repsMax == this.repsMax &&
          other.toFailure == this.toFailure &&
          other.restSeconds == this.restSeconds &&
          other.suggestedWeight == this.suggestedWeight &&
          other.progression == this.progression &&
          other.holdSeconds == this.holdSeconds &&
          other.increment == this.increment &&
          other.successThreshold == this.successThreshold &&
          other.deload == this.deload &&
          other.failureThreshold == this.failureThreshold &&
          other.successStreak == this.successStreak &&
          other.failStreak == this.failStreak);
}

class WorkoutItemsCompanion extends UpdateCompanion<WorkoutItem> {
  final Value<int> id;
  final Value<int> workoutId;
  final Value<int> exerciseId;
  final Value<int> position;
  final Value<int> targetSets;
  final Value<int> repsMin;
  final Value<int?> repsMax;
  final Value<bool> toFailure;
  final Value<int?> restSeconds;
  final Value<double?> suggestedWeight;
  final Value<ProgressionMode> progression;
  final Value<int> holdSeconds;
  final Value<double> increment;
  final Value<int> successThreshold;
  final Value<double> deload;
  final Value<int> failureThreshold;
  final Value<int> successStreak;
  final Value<int> failStreak;
  const WorkoutItemsCompanion({
    this.id = const Value.absent(),
    this.workoutId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.position = const Value.absent(),
    this.targetSets = const Value.absent(),
    this.repsMin = const Value.absent(),
    this.repsMax = const Value.absent(),
    this.toFailure = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.suggestedWeight = const Value.absent(),
    this.progression = const Value.absent(),
    this.holdSeconds = const Value.absent(),
    this.increment = const Value.absent(),
    this.successThreshold = const Value.absent(),
    this.deload = const Value.absent(),
    this.failureThreshold = const Value.absent(),
    this.successStreak = const Value.absent(),
    this.failStreak = const Value.absent(),
  });
  WorkoutItemsCompanion.insert({
    this.id = const Value.absent(),
    required int workoutId,
    required int exerciseId,
    this.position = const Value.absent(),
    this.targetSets = const Value.absent(),
    this.repsMin = const Value.absent(),
    this.repsMax = const Value.absent(),
    this.toFailure = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.suggestedWeight = const Value.absent(),
    this.progression = const Value.absent(),
    this.holdSeconds = const Value.absent(),
    this.increment = const Value.absent(),
    this.successThreshold = const Value.absent(),
    this.deload = const Value.absent(),
    this.failureThreshold = const Value.absent(),
    this.successStreak = const Value.absent(),
    this.failStreak = const Value.absent(),
  }) : workoutId = Value(workoutId),
       exerciseId = Value(exerciseId);
  static Insertable<WorkoutItem> custom({
    Expression<int>? id,
    Expression<int>? workoutId,
    Expression<int>? exerciseId,
    Expression<int>? position,
    Expression<int>? targetSets,
    Expression<int>? repsMin,
    Expression<int>? repsMax,
    Expression<bool>? toFailure,
    Expression<int>? restSeconds,
    Expression<double>? suggestedWeight,
    Expression<String>? progression,
    Expression<int>? holdSeconds,
    Expression<double>? increment,
    Expression<int>? successThreshold,
    Expression<double>? deload,
    Expression<int>? failureThreshold,
    Expression<int>? successStreak,
    Expression<int>? failStreak,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workoutId != null) 'workout_id': workoutId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (position != null) 'position': position,
      if (targetSets != null) 'target_sets': targetSets,
      if (repsMin != null) 'reps_min': repsMin,
      if (repsMax != null) 'reps_max': repsMax,
      if (toFailure != null) 'to_failure': toFailure,
      if (restSeconds != null) 'rest_seconds': restSeconds,
      if (suggestedWeight != null) 'suggested_weight': suggestedWeight,
      if (progression != null) 'progression': progression,
      if (holdSeconds != null) 'hold_seconds': holdSeconds,
      if (increment != null) 'increment': increment,
      if (successThreshold != null) 'success_threshold': successThreshold,
      if (deload != null) 'deload': deload,
      if (failureThreshold != null) 'failure_threshold': failureThreshold,
      if (successStreak != null) 'success_streak': successStreak,
      if (failStreak != null) 'fail_streak': failStreak,
    });
  }

  WorkoutItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? workoutId,
    Value<int>? exerciseId,
    Value<int>? position,
    Value<int>? targetSets,
    Value<int>? repsMin,
    Value<int?>? repsMax,
    Value<bool>? toFailure,
    Value<int?>? restSeconds,
    Value<double?>? suggestedWeight,
    Value<ProgressionMode>? progression,
    Value<int>? holdSeconds,
    Value<double>? increment,
    Value<int>? successThreshold,
    Value<double>? deload,
    Value<int>? failureThreshold,
    Value<int>? successStreak,
    Value<int>? failStreak,
  }) {
    return WorkoutItemsCompanion(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      exerciseId: exerciseId ?? this.exerciseId,
      position: position ?? this.position,
      targetSets: targetSets ?? this.targetSets,
      repsMin: repsMin ?? this.repsMin,
      repsMax: repsMax ?? this.repsMax,
      toFailure: toFailure ?? this.toFailure,
      restSeconds: restSeconds ?? this.restSeconds,
      suggestedWeight: suggestedWeight ?? this.suggestedWeight,
      progression: progression ?? this.progression,
      holdSeconds: holdSeconds ?? this.holdSeconds,
      increment: increment ?? this.increment,
      successThreshold: successThreshold ?? this.successThreshold,
      deload: deload ?? this.deload,
      failureThreshold: failureThreshold ?? this.failureThreshold,
      successStreak: successStreak ?? this.successStreak,
      failStreak: failStreak ?? this.failStreak,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (workoutId.present) {
      map['workout_id'] = Variable<int>(workoutId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (targetSets.present) {
      map['target_sets'] = Variable<int>(targetSets.value);
    }
    if (repsMin.present) {
      map['reps_min'] = Variable<int>(repsMin.value);
    }
    if (repsMax.present) {
      map['reps_max'] = Variable<int>(repsMax.value);
    }
    if (toFailure.present) {
      map['to_failure'] = Variable<bool>(toFailure.value);
    }
    if (restSeconds.present) {
      map['rest_seconds'] = Variable<int>(restSeconds.value);
    }
    if (suggestedWeight.present) {
      map['suggested_weight'] = Variable<double>(suggestedWeight.value);
    }
    if (progression.present) {
      map['progression'] = Variable<String>(
        $WorkoutItemsTable.$converterprogression.toSql(progression.value),
      );
    }
    if (holdSeconds.present) {
      map['hold_seconds'] = Variable<int>(holdSeconds.value);
    }
    if (increment.present) {
      map['increment'] = Variable<double>(increment.value);
    }
    if (successThreshold.present) {
      map['success_threshold'] = Variable<int>(successThreshold.value);
    }
    if (deload.present) {
      map['deload'] = Variable<double>(deload.value);
    }
    if (failureThreshold.present) {
      map['failure_threshold'] = Variable<int>(failureThreshold.value);
    }
    if (successStreak.present) {
      map['success_streak'] = Variable<int>(successStreak.value);
    }
    if (failStreak.present) {
      map['fail_streak'] = Variable<int>(failStreak.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutItemsCompanion(')
          ..write('id: $id, ')
          ..write('workoutId: $workoutId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('position: $position, ')
          ..write('targetSets: $targetSets, ')
          ..write('repsMin: $repsMin, ')
          ..write('repsMax: $repsMax, ')
          ..write('toFailure: $toFailure, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('suggestedWeight: $suggestedWeight, ')
          ..write('progression: $progression, ')
          ..write('holdSeconds: $holdSeconds, ')
          ..write('increment: $increment, ')
          ..write('successThreshold: $successThreshold, ')
          ..write('deload: $deload, ')
          ..write('failureThreshold: $failureThreshold, ')
          ..write('successStreak: $successStreak, ')
          ..write('failStreak: $failStreak')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<int> routineId = GeneratedColumn<int>(
    'routine_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workoutIdMeta = const VerificationMeta(
    'workoutId',
  );
  @override
  late final GeneratedColumn<int> workoutId = GeneratedColumn<int>(
    'workout_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalVolumeMeta = const VerificationMeta(
    'totalVolume',
  );
  @override
  late final GeneratedColumn<double> totalVolume = GeneratedColumn<double>(
    'total_volume',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _setsCompletedMeta = const VerificationMeta(
    'setsCompleted',
  );
  @override
  late final GeneratedColumn<int> setsCompleted = GeneratedColumn<int>(
    'sets_completed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routineId,
    workoutId,
    name,
    startedAt,
    endedAt,
    durationSeconds,
    totalVolume,
    setsCompleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    }
    if (data.containsKey('workout_id')) {
      context.handle(
        _workoutIdMeta,
        workoutId.isAcceptableOrUnknown(data['workout_id']!, _workoutIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('total_volume')) {
      context.handle(
        _totalVolumeMeta,
        totalVolume.isAcceptableOrUnknown(
          data['total_volume']!,
          _totalVolumeMeta,
        ),
      );
    }
    if (data.containsKey('sets_completed')) {
      context.handle(
        _setsCompletedMeta,
        setsCompleted.isAcceptableOrUnknown(
          data['sets_completed']!,
          _setsCompletedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}routine_id'],
      ),
      workoutId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}workout_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      totalVolume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_volume'],
      )!,
      setsCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sets_completed'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final int id;
  final int? routineId;
  final int? workoutId;
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final double totalVolume;
  final int setsCompleted;
  const Session({
    required this.id,
    this.routineId,
    this.workoutId,
    required this.name,
    required this.startedAt,
    this.endedAt,
    required this.durationSeconds,
    required this.totalVolume,
    required this.setsCompleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || routineId != null) {
      map['routine_id'] = Variable<int>(routineId);
    }
    if (!nullToAbsent || workoutId != null) {
      map['workout_id'] = Variable<int>(workoutId);
    }
    map['name'] = Variable<String>(name);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['total_volume'] = Variable<double>(totalVolume);
    map['sets_completed'] = Variable<int>(setsCompleted);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      routineId: routineId == null && nullToAbsent
          ? const Value.absent()
          : Value(routineId),
      workoutId: workoutId == null && nullToAbsent
          ? const Value.absent()
          : Value(workoutId),
      name: Value(name),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      durationSeconds: Value(durationSeconds),
      totalVolume: Value(totalVolume),
      setsCompleted: Value(setsCompleted),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<int>(json['id']),
      routineId: serializer.fromJson<int?>(json['routineId']),
      workoutId: serializer.fromJson<int?>(json['workoutId']),
      name: serializer.fromJson<String>(json['name']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      totalVolume: serializer.fromJson<double>(json['totalVolume']),
      setsCompleted: serializer.fromJson<int>(json['setsCompleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'routineId': serializer.toJson<int?>(routineId),
      'workoutId': serializer.toJson<int?>(workoutId),
      'name': serializer.toJson<String>(name),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'totalVolume': serializer.toJson<double>(totalVolume),
      'setsCompleted': serializer.toJson<int>(setsCompleted),
    };
  }

  Session copyWith({
    int? id,
    Value<int?> routineId = const Value.absent(),
    Value<int?> workoutId = const Value.absent(),
    String? name,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    int? durationSeconds,
    double? totalVolume,
    int? setsCompleted,
  }) => Session(
    id: id ?? this.id,
    routineId: routineId.present ? routineId.value : this.routineId,
    workoutId: workoutId.present ? workoutId.value : this.workoutId,
    name: name ?? this.name,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    totalVolume: totalVolume ?? this.totalVolume,
    setsCompleted: setsCompleted ?? this.setsCompleted,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      workoutId: data.workoutId.present ? data.workoutId.value : this.workoutId,
      name: data.name.present ? data.name.value : this.name,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      totalVolume: data.totalVolume.present
          ? data.totalVolume.value
          : this.totalVolume,
      setsCompleted: data.setsCompleted.present
          ? data.setsCompleted.value
          : this.setsCompleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('workoutId: $workoutId, ')
          ..write('name: $name, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('totalVolume: $totalVolume, ')
          ..write('setsCompleted: $setsCompleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    routineId,
    workoutId,
    name,
    startedAt,
    endedAt,
    durationSeconds,
    totalVolume,
    setsCompleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.workoutId == this.workoutId &&
          other.name == this.name &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.durationSeconds == this.durationSeconds &&
          other.totalVolume == this.totalVolume &&
          other.setsCompleted == this.setsCompleted);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<int> id;
  final Value<int?> routineId;
  final Value<int?> workoutId;
  final Value<String> name;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> durationSeconds;
  final Value<double> totalVolume;
  final Value<int> setsCompleted;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.workoutId = const Value.absent(),
    this.name = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.totalVolume = const Value.absent(),
    this.setsCompleted = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.workoutId = const Value.absent(),
    required String name,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.totalVolume = const Value.absent(),
    this.setsCompleted = const Value.absent(),
  }) : name = Value(name),
       startedAt = Value(startedAt);
  static Insertable<Session> custom({
    Expression<int>? id,
    Expression<int>? routineId,
    Expression<int>? workoutId,
    Expression<String>? name,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? durationSeconds,
    Expression<double>? totalVolume,
    Expression<int>? setsCompleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (workoutId != null) 'workout_id': workoutId,
      if (name != null) 'name': name,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (totalVolume != null) 'total_volume': totalVolume,
      if (setsCompleted != null) 'sets_completed': setsCompleted,
    });
  }

  SessionsCompanion copyWith({
    Value<int>? id,
    Value<int?>? routineId,
    Value<int?>? workoutId,
    Value<String>? name,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? durationSeconds,
    Value<double>? totalVolume,
    Value<int>? setsCompleted,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      workoutId: workoutId ?? this.workoutId,
      name: name ?? this.name,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      totalVolume: totalVolume ?? this.totalVolume,
      setsCompleted: setsCompleted ?? this.setsCompleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<int>(routineId.value);
    }
    if (workoutId.present) {
      map['workout_id'] = Variable<int>(workoutId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (totalVolume.present) {
      map['total_volume'] = Variable<double>(totalVolume.value);
    }
    if (setsCompleted.present) {
      map['sets_completed'] = Variable<int>(setsCompleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('workoutId: $workoutId, ')
          ..write('name: $name, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('totalVolume: $totalVolume, ')
          ..write('setsCompleted: $setsCompleted')
          ..write(')'))
        .toString();
  }
}

class $SessionSetsTable extends SessionSets
    with TableInfo<$SessionSetsTable, SessionSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exerciseNameMeta = const VerificationMeta(
    'exerciseName',
  );
  @override
  late final GeneratedColumn<String> exerciseName = GeneratedColumn<String>(
    'exercise_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setNumberMeta = const VerificationMeta(
    'setNumber',
  );
  @override
  late final GeneratedColumn<int> setNumber = GeneratedColumn<int>(
    'set_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _goalRepsMeta = const VerificationMeta(
    'goalReps',
  );
  @override
  late final GeneratedColumn<int> goalReps = GeneratedColumn<int>(
    'goal_reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _goalWeightMeta = const VerificationMeta(
    'goalWeight',
  );
  @override
  late final GeneratedColumn<double> goalWeight = GeneratedColumn<double>(
    'goal_weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _secondsMeta = const VerificationMeta(
    'seconds',
  );
  @override
  late final GeneratedColumn<int> seconds = GeneratedColumn<int>(
    'seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalSecondsMeta = const VerificationMeta(
    'goalSeconds',
  );
  @override
  late final GeneratedColumn<int> goalSeconds = GeneratedColumn<int>(
    'goal_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    exerciseId,
    exerciseName,
    setNumber,
    weight,
    reps,
    done,
    goalReps,
    goalWeight,
    seconds,
    goalSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    }
    if (data.containsKey('exercise_name')) {
      context.handle(
        _exerciseNameMeta,
        exerciseName.isAcceptableOrUnknown(
          data['exercise_name']!,
          _exerciseNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseNameMeta);
    }
    if (data.containsKey('set_number')) {
      context.handle(
        _setNumberMeta,
        setNumber.isAcceptableOrUnknown(data['set_number']!, _setNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_setNumberMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('goal_reps')) {
      context.handle(
        _goalRepsMeta,
        goalReps.isAcceptableOrUnknown(data['goal_reps']!, _goalRepsMeta),
      );
    }
    if (data.containsKey('goal_weight')) {
      context.handle(
        _goalWeightMeta,
        goalWeight.isAcceptableOrUnknown(data['goal_weight']!, _goalWeightMeta),
      );
    }
    if (data.containsKey('seconds')) {
      context.handle(
        _secondsMeta,
        seconds.isAcceptableOrUnknown(data['seconds']!, _secondsMeta),
      );
    }
    if (data.containsKey('goal_seconds')) {
      context.handle(
        _goalSecondsMeta,
        goalSeconds.isAcceptableOrUnknown(
          data['goal_seconds']!,
          _goalSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exercise_id'],
      ),
      exerciseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_name'],
      )!,
      setNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_number'],
      )!,
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      goalReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}goal_reps'],
      )!,
      goalWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}goal_weight'],
      ),
      seconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seconds'],
      ),
      goalSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}goal_seconds'],
      ),
    );
  }

  @override
  $SessionSetsTable createAlias(String alias) {
    return $SessionSetsTable(attachedDatabase, alias);
  }
}

class SessionSet extends DataClass implements Insertable<SessionSet> {
  final int id;
  final int sessionId;
  final int? exerciseId;
  final String exerciseName;
  final int setNumber;
  final double weight;
  final int reps;
  final bool done;

  /// What the set was aiming for, captured as it was logged.
  ///
  /// Stored rather than looked up from the template later: templates get
  /// edited, and progression has to know what you were actually chasing on the
  /// day. Zero means "no goal recorded" — every set logged before schema v3.
  final int goalReps;

  /// The weight the template suggested, in kg. Null when it suggested none.
  final double? goalWeight;

  /// Seconds held, on a set measured in time rather than reps.
  ///
  /// A separate column rather than a reinterpretation of [reps]: a 60-second
  /// plank is not sixty repetitions, and folding it into the rep count would
  /// quietly inflate lifetime reps and volume alike. Null on a counted set.
  final int? seconds;

  /// The hold the template was asking for, in seconds. Null when the set was
  /// counted in reps.
  final int? goalSeconds;
  const SessionSet({
    required this.id,
    required this.sessionId,
    this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.done,
    required this.goalReps,
    this.goalWeight,
    this.seconds,
    this.goalSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    if (!nullToAbsent || exerciseId != null) {
      map['exercise_id'] = Variable<int>(exerciseId);
    }
    map['exercise_name'] = Variable<String>(exerciseName);
    map['set_number'] = Variable<int>(setNumber);
    map['weight'] = Variable<double>(weight);
    map['reps'] = Variable<int>(reps);
    map['done'] = Variable<bool>(done);
    map['goal_reps'] = Variable<int>(goalReps);
    if (!nullToAbsent || goalWeight != null) {
      map['goal_weight'] = Variable<double>(goalWeight);
    }
    if (!nullToAbsent || seconds != null) {
      map['seconds'] = Variable<int>(seconds);
    }
    if (!nullToAbsent || goalSeconds != null) {
      map['goal_seconds'] = Variable<int>(goalSeconds);
    }
    return map;
  }

  SessionSetsCompanion toCompanion(bool nullToAbsent) {
    return SessionSetsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      exerciseId: exerciseId == null && nullToAbsent
          ? const Value.absent()
          : Value(exerciseId),
      exerciseName: Value(exerciseName),
      setNumber: Value(setNumber),
      weight: Value(weight),
      reps: Value(reps),
      done: Value(done),
      goalReps: Value(goalReps),
      goalWeight: goalWeight == null && nullToAbsent
          ? const Value.absent()
          : Value(goalWeight),
      seconds: seconds == null && nullToAbsent
          ? const Value.absent()
          : Value(seconds),
      goalSeconds: goalSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(goalSeconds),
    );
  }

  factory SessionSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionSet(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      exerciseId: serializer.fromJson<int?>(json['exerciseId']),
      exerciseName: serializer.fromJson<String>(json['exerciseName']),
      setNumber: serializer.fromJson<int>(json['setNumber']),
      weight: serializer.fromJson<double>(json['weight']),
      reps: serializer.fromJson<int>(json['reps']),
      done: serializer.fromJson<bool>(json['done']),
      goalReps: serializer.fromJson<int>(json['goalReps']),
      goalWeight: serializer.fromJson<double?>(json['goalWeight']),
      seconds: serializer.fromJson<int?>(json['seconds']),
      goalSeconds: serializer.fromJson<int?>(json['goalSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'exerciseId': serializer.toJson<int?>(exerciseId),
      'exerciseName': serializer.toJson<String>(exerciseName),
      'setNumber': serializer.toJson<int>(setNumber),
      'weight': serializer.toJson<double>(weight),
      'reps': serializer.toJson<int>(reps),
      'done': serializer.toJson<bool>(done),
      'goalReps': serializer.toJson<int>(goalReps),
      'goalWeight': serializer.toJson<double?>(goalWeight),
      'seconds': serializer.toJson<int?>(seconds),
      'goalSeconds': serializer.toJson<int?>(goalSeconds),
    };
  }

  SessionSet copyWith({
    int? id,
    int? sessionId,
    Value<int?> exerciseId = const Value.absent(),
    String? exerciseName,
    int? setNumber,
    double? weight,
    int? reps,
    bool? done,
    int? goalReps,
    Value<double?> goalWeight = const Value.absent(),
    Value<int?> seconds = const Value.absent(),
    Value<int?> goalSeconds = const Value.absent(),
  }) => SessionSet(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    exerciseId: exerciseId.present ? exerciseId.value : this.exerciseId,
    exerciseName: exerciseName ?? this.exerciseName,
    setNumber: setNumber ?? this.setNumber,
    weight: weight ?? this.weight,
    reps: reps ?? this.reps,
    done: done ?? this.done,
    goalReps: goalReps ?? this.goalReps,
    goalWeight: goalWeight.present ? goalWeight.value : this.goalWeight,
    seconds: seconds.present ? seconds.value : this.seconds,
    goalSeconds: goalSeconds.present ? goalSeconds.value : this.goalSeconds,
  );
  SessionSet copyWithCompanion(SessionSetsCompanion data) {
    return SessionSet(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      exerciseName: data.exerciseName.present
          ? data.exerciseName.value
          : this.exerciseName,
      setNumber: data.setNumber.present ? data.setNumber.value : this.setNumber,
      weight: data.weight.present ? data.weight.value : this.weight,
      reps: data.reps.present ? data.reps.value : this.reps,
      done: data.done.present ? data.done.value : this.done,
      goalReps: data.goalReps.present ? data.goalReps.value : this.goalReps,
      goalWeight: data.goalWeight.present
          ? data.goalWeight.value
          : this.goalWeight,
      seconds: data.seconds.present ? data.seconds.value : this.seconds,
      goalSeconds: data.goalSeconds.present
          ? data.goalSeconds.value
          : this.goalSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionSet(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('setNumber: $setNumber, ')
          ..write('weight: $weight, ')
          ..write('reps: $reps, ')
          ..write('done: $done, ')
          ..write('goalReps: $goalReps, ')
          ..write('goalWeight: $goalWeight, ')
          ..write('seconds: $seconds, ')
          ..write('goalSeconds: $goalSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    exerciseId,
    exerciseName,
    setNumber,
    weight,
    reps,
    done,
    goalReps,
    goalWeight,
    seconds,
    goalSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionSet &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.exerciseId == this.exerciseId &&
          other.exerciseName == this.exerciseName &&
          other.setNumber == this.setNumber &&
          other.weight == this.weight &&
          other.reps == this.reps &&
          other.done == this.done &&
          other.goalReps == this.goalReps &&
          other.goalWeight == this.goalWeight &&
          other.seconds == this.seconds &&
          other.goalSeconds == this.goalSeconds);
}

class SessionSetsCompanion extends UpdateCompanion<SessionSet> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int?> exerciseId;
  final Value<String> exerciseName;
  final Value<int> setNumber;
  final Value<double> weight;
  final Value<int> reps;
  final Value<bool> done;
  final Value<int> goalReps;
  final Value<double?> goalWeight;
  final Value<int?> seconds;
  final Value<int?> goalSeconds;
  const SessionSetsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.exerciseName = const Value.absent(),
    this.setNumber = const Value.absent(),
    this.weight = const Value.absent(),
    this.reps = const Value.absent(),
    this.done = const Value.absent(),
    this.goalReps = const Value.absent(),
    this.goalWeight = const Value.absent(),
    this.seconds = const Value.absent(),
    this.goalSeconds = const Value.absent(),
  });
  SessionSetsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    this.exerciseId = const Value.absent(),
    required String exerciseName,
    required int setNumber,
    this.weight = const Value.absent(),
    this.reps = const Value.absent(),
    this.done = const Value.absent(),
    this.goalReps = const Value.absent(),
    this.goalWeight = const Value.absent(),
    this.seconds = const Value.absent(),
    this.goalSeconds = const Value.absent(),
  }) : sessionId = Value(sessionId),
       exerciseName = Value(exerciseName),
       setNumber = Value(setNumber);
  static Insertable<SessionSet> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? exerciseId,
    Expression<String>? exerciseName,
    Expression<int>? setNumber,
    Expression<double>? weight,
    Expression<int>? reps,
    Expression<bool>? done,
    Expression<int>? goalReps,
    Expression<double>? goalWeight,
    Expression<int>? seconds,
    Expression<int>? goalSeconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (exerciseName != null) 'exercise_name': exerciseName,
      if (setNumber != null) 'set_number': setNumber,
      if (weight != null) 'weight': weight,
      if (reps != null) 'reps': reps,
      if (done != null) 'done': done,
      if (goalReps != null) 'goal_reps': goalReps,
      if (goalWeight != null) 'goal_weight': goalWeight,
      if (seconds != null) 'seconds': seconds,
      if (goalSeconds != null) 'goal_seconds': goalSeconds,
    });
  }

  SessionSetsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<int?>? exerciseId,
    Value<String>? exerciseName,
    Value<int>? setNumber,
    Value<double>? weight,
    Value<int>? reps,
    Value<bool>? done,
    Value<int>? goalReps,
    Value<double?>? goalWeight,
    Value<int?>? seconds,
    Value<int?>? goalSeconds,
  }) {
    return SessionSetsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      setNumber: setNumber ?? this.setNumber,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      done: done ?? this.done,
      goalReps: goalReps ?? this.goalReps,
      goalWeight: goalWeight ?? this.goalWeight,
      seconds: seconds ?? this.seconds,
      goalSeconds: goalSeconds ?? this.goalSeconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (exerciseName.present) {
      map['exercise_name'] = Variable<String>(exerciseName.value);
    }
    if (setNumber.present) {
      map['set_number'] = Variable<int>(setNumber.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (goalReps.present) {
      map['goal_reps'] = Variable<int>(goalReps.value);
    }
    if (goalWeight.present) {
      map['goal_weight'] = Variable<double>(goalWeight.value);
    }
    if (seconds.present) {
      map['seconds'] = Variable<int>(seconds.value);
    }
    if (goalSeconds.present) {
      map['goal_seconds'] = Variable<int>(goalSeconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionSetsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('setNumber: $setNumber, ')
          ..write('weight: $weight, ')
          ..write('reps: $reps, ')
          ..write('done: $done, ')
          ..write('goalReps: $goalReps, ')
          ..write('goalWeight: $goalWeight, ')
          ..write('seconds: $seconds, ')
          ..write('goalSeconds: $goalSeconds')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _weightUnitMeta = const VerificationMeta(
    'weightUnit',
  );
  @override
  late final GeneratedColumn<String> weightUnit = GeneratedColumn<String>(
    'weight_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('kg'),
  );
  static const VerificationMeta _activeRoutineIdMeta = const VerificationMeta(
    'activeRoutineId',
  );
  @override
  late final GeneratedColumn<int> activeRoutineId = GeneratedColumn<int>(
    'active_routine_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, weightUnit, activeRoutineId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('weight_unit')) {
      context.handle(
        _weightUnitMeta,
        weightUnit.isAcceptableOrUnknown(data['weight_unit']!, _weightUnitMeta),
      );
    }
    if (data.containsKey('active_routine_id')) {
      context.handle(
        _activeRoutineIdMeta,
        activeRoutineId.isAcceptableOrUnknown(
          data['active_routine_id']!,
          _activeRoutineIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      weightUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weight_unit'],
      )!,
      activeRoutineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_routine_id'],
      ),
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final int id;

  /// 'kg' or 'lb'. Weights are stored in kg; this only affects display/input.
  final String weightUnit;

  /// The routine the Today tab is currently about. Null means "not chosen yet",
  /// which makes Today fall back to a routine chooser. Not a foreign key: a
  /// dangling id after a delete resolves to null rather than failing.
  final int? activeRoutineId;
  const Setting({
    required this.id,
    required this.weightUnit,
    this.activeRoutineId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['weight_unit'] = Variable<String>(weightUnit);
    if (!nullToAbsent || activeRoutineId != null) {
      map['active_routine_id'] = Variable<int>(activeRoutineId);
    }
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      weightUnit: Value(weightUnit),
      activeRoutineId: activeRoutineId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeRoutineId),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      id: serializer.fromJson<int>(json['id']),
      weightUnit: serializer.fromJson<String>(json['weightUnit']),
      activeRoutineId: serializer.fromJson<int?>(json['activeRoutineId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'weightUnit': serializer.toJson<String>(weightUnit),
      'activeRoutineId': serializer.toJson<int?>(activeRoutineId),
    };
  }

  Setting copyWith({
    int? id,
    String? weightUnit,
    Value<int?> activeRoutineId = const Value.absent(),
  }) => Setting(
    id: id ?? this.id,
    weightUnit: weightUnit ?? this.weightUnit,
    activeRoutineId: activeRoutineId.present
        ? activeRoutineId.value
        : this.activeRoutineId,
  );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      id: data.id.present ? data.id.value : this.id,
      weightUnit: data.weightUnit.present
          ? data.weightUnit.value
          : this.weightUnit,
      activeRoutineId: data.activeRoutineId.present
          ? data.activeRoutineId.value
          : this.activeRoutineId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('id: $id, ')
          ..write('weightUnit: $weightUnit, ')
          ..write('activeRoutineId: $activeRoutineId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, weightUnit, activeRoutineId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.id == this.id &&
          other.weightUnit == this.weightUnit &&
          other.activeRoutineId == this.activeRoutineId);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<int> id;
  final Value<String> weightUnit;
  final Value<int?> activeRoutineId;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.weightUnit = const Value.absent(),
    this.activeRoutineId = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    this.weightUnit = const Value.absent(),
    this.activeRoutineId = const Value.absent(),
  });
  static Insertable<Setting> custom({
    Expression<int>? id,
    Expression<String>? weightUnit,
    Expression<int>? activeRoutineId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (weightUnit != null) 'weight_unit': weightUnit,
      if (activeRoutineId != null) 'active_routine_id': activeRoutineId,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? weightUnit,
    Value<int?>? activeRoutineId,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      weightUnit: weightUnit ?? this.weightUnit,
      activeRoutineId: activeRoutineId ?? this.activeRoutineId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (weightUnit.present) {
      map['weight_unit'] = Variable<String>(weightUnit.value);
    }
    if (activeRoutineId.present) {
      map['active_routine_id'] = Variable<int>(activeRoutineId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('weightUnit: $weightUnit, ')
          ..write('activeRoutineId: $activeRoutineId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $RoutinesTable routines = $RoutinesTable(this);
  late final $WorkoutsTable workouts = $WorkoutsTable(this);
  late final $WorkoutItemsTable workoutItems = $WorkoutItemsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $SessionSetsTable sessionSets = $SessionSetsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    exercises,
    routines,
    workouts,
    workoutItems,
    sessions,
    sessionSets,
    settings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'routines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workouts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workouts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workout_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('session_sets', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ExercisesTableCreateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      required String name,
      Value<String> muscleGroup,
      Value<String> equipment,
      Value<String> instructions,
      Value<String?> videoUrl,
      Value<bool> isCustom,
    });
typedef $$ExercisesTableUpdateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> muscleGroup,
      Value<String> equipment,
      Value<String> instructions,
      Value<String?> videoUrl,
      Value<bool> isCustom,
    });

final class $$ExercisesTableReferences
    extends BaseReferences<_$AppDatabase, $ExercisesTable, Exercise> {
  $$ExercisesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WorkoutItemsTable, List<WorkoutItem>>
  _workoutItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workoutItems,
    aliasName: 'exercises__id__workout_items__exercise_id',
  );

  $$WorkoutItemsTableProcessedTableManager get workoutItemsRefs {
    final manager = $$WorkoutItemsTableTableManager(
      $_db,
      $_db.workoutItems,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_workoutItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> workoutItemsRefs(
    Expression<bool> Function($$WorkoutItemsTableFilterComposer f) f,
  ) {
    final $$WorkoutItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutItems,
      getReferencedColumn: (t) => t.exerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutItemsTableFilterComposer(
            $db: $db,
            $table: $db.workoutItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get equipment =>
      $composableBuilder(column: $table.equipment, builder: (column) => column);

  GeneratedColumn<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoUrl =>
      $composableBuilder(column: $table.videoUrl, builder: (column) => column);

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  Expression<T> workoutItemsRefs<T extends Object>(
    Expression<T> Function($$WorkoutItemsTableAnnotationComposer a) f,
  ) {
    final $$WorkoutItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutItems,
      getReferencedColumn: (t) => t.exerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExercisesTable,
          Exercise,
          $$ExercisesTableFilterComposer,
          $$ExercisesTableOrderingComposer,
          $$ExercisesTableAnnotationComposer,
          $$ExercisesTableCreateCompanionBuilder,
          $$ExercisesTableUpdateCompanionBuilder,
          (Exercise, $$ExercisesTableReferences),
          Exercise,
          PrefetchHooks Function({bool workoutItemsRefs})
        > {
  $$ExercisesTableTableManager(_$AppDatabase db, $ExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> muscleGroup = const Value.absent(),
                Value<String> equipment = const Value.absent(),
                Value<String> instructions = const Value.absent(),
                Value<String?> videoUrl = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                name: name,
                muscleGroup: muscleGroup,
                equipment: equipment,
                instructions: instructions,
                videoUrl: videoUrl,
                isCustom: isCustom,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> muscleGroup = const Value.absent(),
                Value<String> equipment = const Value.absent(),
                Value<String> instructions = const Value.absent(),
                Value<String?> videoUrl = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                name: name,
                muscleGroup: muscleGroup,
                equipment: equipment,
                instructions: instructions,
                videoUrl: videoUrl,
                isCustom: isCustom,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExercisesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workoutItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (workoutItemsRefs) db.workoutItems],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (workoutItemsRefs)
                    await $_getPrefetchedData<
                      Exercise,
                      $ExercisesTable,
                      WorkoutItem
                    >(
                      currentTable: table,
                      referencedTable: $$ExercisesTableReferences
                          ._workoutItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ExercisesTableReferences(
                            db,
                            table,
                            p0,
                          ).workoutItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.exerciseId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExercisesTable,
      Exercise,
      $$ExercisesTableFilterComposer,
      $$ExercisesTableOrderingComposer,
      $$ExercisesTableAnnotationComposer,
      $$ExercisesTableCreateCompanionBuilder,
      $$ExercisesTableUpdateCompanionBuilder,
      (Exercise, $$ExercisesTableReferences),
      Exercise,
      PrefetchHooks Function({bool workoutItemsRefs})
    >;
typedef $$RoutinesTableCreateCompanionBuilder =
    RoutinesCompanion Function({
      Value<int> id,
      required String name,
      Value<String> colorHex,
      Value<int> position,
      Value<int> restSeconds,
    });
typedef $$RoutinesTableUpdateCompanionBuilder =
    RoutinesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> colorHex,
      Value<int> position,
      Value<int> restSeconds,
    });

final class $$RoutinesTableReferences
    extends BaseReferences<_$AppDatabase, $RoutinesTable, Routine> {
  $$RoutinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WorkoutsTable, List<Workout>> _workoutsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.workouts,
    aliasName: 'routines__id__workouts__routine_id',
  );

  $$WorkoutsTableProcessedTableManager get workoutsRefs {
    final manager = $$WorkoutsTableTableManager(
      $_db,
      $_db.workouts,
    ).filter((f) => f.routineId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_workoutsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RoutinesTableFilterComposer
    extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> workoutsRefs(
    Expression<bool> Function($$WorkoutsTableFilterComposer f) f,
  ) {
    final $$WorkoutsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workouts,
      getReferencedColumn: (t) => t.routineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableFilterComposer(
            $db: $db,
            $table: $db.workouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutinesTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => column,
  );

  Expression<T> workoutsRefs<T extends Object>(
    Expression<T> Function($$WorkoutsTableAnnotationComposer a) f,
  ) {
    final $$WorkoutsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workouts,
      getReferencedColumn: (t) => t.routineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableAnnotationComposer(
            $db: $db,
            $table: $db.workouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutinesTable,
          Routine,
          $$RoutinesTableFilterComposer,
          $$RoutinesTableOrderingComposer,
          $$RoutinesTableAnnotationComposer,
          $$RoutinesTableCreateCompanionBuilder,
          $$RoutinesTableUpdateCompanionBuilder,
          (Routine, $$RoutinesTableReferences),
          Routine,
          PrefetchHooks Function({bool workoutsRefs})
        > {
  $$RoutinesTableTableManager(_$AppDatabase db, $RoutinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> restSeconds = const Value.absent(),
              }) => RoutinesCompanion(
                id: id,
                name: name,
                colorHex: colorHex,
                position: position,
                restSeconds: restSeconds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> colorHex = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> restSeconds = const Value.absent(),
              }) => RoutinesCompanion.insert(
                id: id,
                name: name,
                colorHex: colorHex,
                position: position,
                restSeconds: restSeconds,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RoutinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workoutsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (workoutsRefs) db.workouts],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (workoutsRefs)
                    await $_getPrefetchedData<Routine, $RoutinesTable, Workout>(
                      currentTable: table,
                      referencedTable: $$RoutinesTableReferences
                          ._workoutsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RoutinesTableReferences(db, table, p0).workoutsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.routineId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RoutinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutinesTable,
      Routine,
      $$RoutinesTableFilterComposer,
      $$RoutinesTableOrderingComposer,
      $$RoutinesTableAnnotationComposer,
      $$RoutinesTableCreateCompanionBuilder,
      $$RoutinesTableUpdateCompanionBuilder,
      (Routine, $$RoutinesTableReferences),
      Routine,
      PrefetchHooks Function({bool workoutsRefs})
    >;
typedef $$WorkoutsTableCreateCompanionBuilder =
    WorkoutsCompanion Function({
      Value<int> id,
      required int routineId,
      required String name,
      Value<int> position,
    });
typedef $$WorkoutsTableUpdateCompanionBuilder =
    WorkoutsCompanion Function({
      Value<int> id,
      Value<int> routineId,
      Value<String> name,
      Value<int> position,
    });

final class $$WorkoutsTableReferences
    extends BaseReferences<_$AppDatabase, $WorkoutsTable, Workout> {
  $$WorkoutsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RoutinesTable _routineIdTable(_$AppDatabase db) =>
      db.routines.createAlias('workouts__routine_id__routines__id');

  $$RoutinesTableProcessedTableManager get routineId {
    final $_column = $_itemColumn<int>('routine_id')!;

    final manager = $$RoutinesTableTableManager(
      $_db,
      $_db.routines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_routineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$WorkoutItemsTable, List<WorkoutItem>>
  _workoutItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workoutItems,
    aliasName: 'workouts__id__workout_items__workout_id',
  );

  $$WorkoutItemsTableProcessedTableManager get workoutItemsRefs {
    final manager = $$WorkoutItemsTableTableManager(
      $_db,
      $_db.workoutItems,
    ).filter((f) => f.workoutId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_workoutItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutsTable> {
  $$WorkoutsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$RoutinesTableFilterComposer get routineId {
    final $$RoutinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableFilterComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> workoutItemsRefs(
    Expression<bool> Function($$WorkoutItemsTableFilterComposer f) f,
  ) {
    final $$WorkoutItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutItems,
      getReferencedColumn: (t) => t.workoutId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutItemsTableFilterComposer(
            $db: $db,
            $table: $db.workoutItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutsTable> {
  $$WorkoutsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$RoutinesTableOrderingComposer get routineId {
    final $$RoutinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableOrderingComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutsTable> {
  $$WorkoutsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$RoutinesTableAnnotationComposer get routineId {
    final $$RoutinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutinesTableAnnotationComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> workoutItemsRefs<T extends Object>(
    Expression<T> Function($$WorkoutItemsTableAnnotationComposer a) f,
  ) {
    final $$WorkoutItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutItems,
      getReferencedColumn: (t) => t.workoutId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutsTable,
          Workout,
          $$WorkoutsTableFilterComposer,
          $$WorkoutsTableOrderingComposer,
          $$WorkoutsTableAnnotationComposer,
          $$WorkoutsTableCreateCompanionBuilder,
          $$WorkoutsTableUpdateCompanionBuilder,
          (Workout, $$WorkoutsTableReferences),
          Workout,
          PrefetchHooks Function({bool routineId, bool workoutItemsRefs})
        > {
  $$WorkoutsTableTableManager(_$AppDatabase db, $WorkoutsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> routineId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> position = const Value.absent(),
              }) => WorkoutsCompanion(
                id: id,
                routineId: routineId,
                name: name,
                position: position,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int routineId,
                required String name,
                Value<int> position = const Value.absent(),
              }) => WorkoutsCompanion.insert(
                id: id,
                routineId: routineId,
                name: name,
                position: position,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkoutsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({routineId = false, workoutItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workoutItemsRefs) db.workoutItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (routineId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.routineId,
                                    referencedTable: $$WorkoutsTableReferences
                                        ._routineIdTable(db),
                                    referencedColumn: $$WorkoutsTableReferences
                                        ._routineIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workoutItemsRefs)
                        await $_getPrefetchedData<
                          Workout,
                          $WorkoutsTable,
                          WorkoutItem
                        >(
                          currentTable: table,
                          referencedTable: $$WorkoutsTableReferences
                              ._workoutItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkoutsTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workoutId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WorkoutsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutsTable,
      Workout,
      $$WorkoutsTableFilterComposer,
      $$WorkoutsTableOrderingComposer,
      $$WorkoutsTableAnnotationComposer,
      $$WorkoutsTableCreateCompanionBuilder,
      $$WorkoutsTableUpdateCompanionBuilder,
      (Workout, $$WorkoutsTableReferences),
      Workout,
      PrefetchHooks Function({bool routineId, bool workoutItemsRefs})
    >;
typedef $$WorkoutItemsTableCreateCompanionBuilder =
    WorkoutItemsCompanion Function({
      Value<int> id,
      required int workoutId,
      required int exerciseId,
      Value<int> position,
      Value<int> targetSets,
      Value<int> repsMin,
      Value<int?> repsMax,
      Value<bool> toFailure,
      Value<int?> restSeconds,
      Value<double?> suggestedWeight,
      Value<ProgressionMode> progression,
      Value<int> holdSeconds,
      Value<double> increment,
      Value<int> successThreshold,
      Value<double> deload,
      Value<int> failureThreshold,
      Value<int> successStreak,
      Value<int> failStreak,
    });
typedef $$WorkoutItemsTableUpdateCompanionBuilder =
    WorkoutItemsCompanion Function({
      Value<int> id,
      Value<int> workoutId,
      Value<int> exerciseId,
      Value<int> position,
      Value<int> targetSets,
      Value<int> repsMin,
      Value<int?> repsMax,
      Value<bool> toFailure,
      Value<int?> restSeconds,
      Value<double?> suggestedWeight,
      Value<ProgressionMode> progression,
      Value<int> holdSeconds,
      Value<double> increment,
      Value<int> successThreshold,
      Value<double> deload,
      Value<int> failureThreshold,
      Value<int> successStreak,
      Value<int> failStreak,
    });

final class $$WorkoutItemsTableReferences
    extends BaseReferences<_$AppDatabase, $WorkoutItemsTable, WorkoutItem> {
  $$WorkoutItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorkoutsTable _workoutIdTable(_$AppDatabase db) =>
      db.workouts.createAlias('workout_items__workout_id__workouts__id');

  $$WorkoutsTableProcessedTableManager get workoutId {
    final $_column = $_itemColumn<int>('workout_id')!;

    final manager = $$WorkoutsTableTableManager(
      $_db,
      $_db.workouts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workoutIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) =>
      db.exercises.createAlias('workout_items__exercise_id__exercises__id');

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<int>('exercise_id')!;

    final manager = $$ExercisesTableTableManager(
      $_db,
      $_db.exercises,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkoutItemsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutItemsTable> {
  $$WorkoutItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repsMin => $composableBuilder(
    column: $table.repsMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repsMax => $composableBuilder(
    column: $table.repsMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get toFailure => $composableBuilder(
    column: $table.toFailure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get suggestedWeight => $composableBuilder(
    column: $table.suggestedWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ProgressionMode, ProgressionMode, String>
  get progression => $composableBuilder(
    column: $table.progression,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get holdSeconds => $composableBuilder(
    column: $table.holdSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get increment => $composableBuilder(
    column: $table.increment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get successThreshold => $composableBuilder(
    column: $table.successThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get deload => $composableBuilder(
    column: $table.deload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failureThreshold => $composableBuilder(
    column: $table.failureThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get successStreak => $composableBuilder(
    column: $table.successStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failStreak => $composableBuilder(
    column: $table.failStreak,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkoutsTableFilterComposer get workoutId {
    final $$WorkoutsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workouts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableFilterComposer(
            $db: $db,
            $table: $db.workouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutItemsTable> {
  $$WorkoutItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repsMin => $composableBuilder(
    column: $table.repsMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repsMax => $composableBuilder(
    column: $table.repsMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get toFailure => $composableBuilder(
    column: $table.toFailure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get suggestedWeight => $composableBuilder(
    column: $table.suggestedWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get progression => $composableBuilder(
    column: $table.progression,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get holdSeconds => $composableBuilder(
    column: $table.holdSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get increment => $composableBuilder(
    column: $table.increment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get successThreshold => $composableBuilder(
    column: $table.successThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get deload => $composableBuilder(
    column: $table.deload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failureThreshold => $composableBuilder(
    column: $table.failureThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get successStreak => $composableBuilder(
    column: $table.successStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failStreak => $composableBuilder(
    column: $table.failStreak,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutsTableOrderingComposer get workoutId {
    final $$WorkoutsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workouts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableOrderingComposer(
            $db: $db,
            $table: $db.workouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutItemsTable> {
  $$WorkoutItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repsMin =>
      $composableBuilder(column: $table.repsMin, builder: (column) => column);

  GeneratedColumn<int> get repsMax =>
      $composableBuilder(column: $table.repsMax, builder: (column) => column);

  GeneratedColumn<bool> get toFailure =>
      $composableBuilder(column: $table.toFailure, builder: (column) => column);

  GeneratedColumn<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get suggestedWeight => $composableBuilder(
    column: $table.suggestedWeight,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ProgressionMode, String> get progression =>
      $composableBuilder(
        column: $table.progression,
        builder: (column) => column,
      );

  GeneratedColumn<int> get holdSeconds => $composableBuilder(
    column: $table.holdSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get increment =>
      $composableBuilder(column: $table.increment, builder: (column) => column);

  GeneratedColumn<int> get successThreshold => $composableBuilder(
    column: $table.successThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<double> get deload =>
      $composableBuilder(column: $table.deload, builder: (column) => column);

  GeneratedColumn<int> get failureThreshold => $composableBuilder(
    column: $table.failureThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<int> get successStreak => $composableBuilder(
    column: $table.successStreak,
    builder: (column) => column,
  );

  GeneratedColumn<int> get failStreak => $composableBuilder(
    column: $table.failStreak,
    builder: (column) => column,
  );

  $$WorkoutsTableAnnotationComposer get workoutId {
    final $$WorkoutsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workouts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutsTableAnnotationComposer(
            $db: $db,
            $table: $db.workouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutItemsTable,
          WorkoutItem,
          $$WorkoutItemsTableFilterComposer,
          $$WorkoutItemsTableOrderingComposer,
          $$WorkoutItemsTableAnnotationComposer,
          $$WorkoutItemsTableCreateCompanionBuilder,
          $$WorkoutItemsTableUpdateCompanionBuilder,
          (WorkoutItem, $$WorkoutItemsTableReferences),
          WorkoutItem,
          PrefetchHooks Function({bool workoutId, bool exerciseId})
        > {
  $$WorkoutItemsTableTableManager(_$AppDatabase db, $WorkoutItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> workoutId = const Value.absent(),
                Value<int> exerciseId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> targetSets = const Value.absent(),
                Value<int> repsMin = const Value.absent(),
                Value<int?> repsMax = const Value.absent(),
                Value<bool> toFailure = const Value.absent(),
                Value<int?> restSeconds = const Value.absent(),
                Value<double?> suggestedWeight = const Value.absent(),
                Value<ProgressionMode> progression = const Value.absent(),
                Value<int> holdSeconds = const Value.absent(),
                Value<double> increment = const Value.absent(),
                Value<int> successThreshold = const Value.absent(),
                Value<double> deload = const Value.absent(),
                Value<int> failureThreshold = const Value.absent(),
                Value<int> successStreak = const Value.absent(),
                Value<int> failStreak = const Value.absent(),
              }) => WorkoutItemsCompanion(
                id: id,
                workoutId: workoutId,
                exerciseId: exerciseId,
                position: position,
                targetSets: targetSets,
                repsMin: repsMin,
                repsMax: repsMax,
                toFailure: toFailure,
                restSeconds: restSeconds,
                suggestedWeight: suggestedWeight,
                progression: progression,
                holdSeconds: holdSeconds,
                increment: increment,
                successThreshold: successThreshold,
                deload: deload,
                failureThreshold: failureThreshold,
                successStreak: successStreak,
                failStreak: failStreak,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int workoutId,
                required int exerciseId,
                Value<int> position = const Value.absent(),
                Value<int> targetSets = const Value.absent(),
                Value<int> repsMin = const Value.absent(),
                Value<int?> repsMax = const Value.absent(),
                Value<bool> toFailure = const Value.absent(),
                Value<int?> restSeconds = const Value.absent(),
                Value<double?> suggestedWeight = const Value.absent(),
                Value<ProgressionMode> progression = const Value.absent(),
                Value<int> holdSeconds = const Value.absent(),
                Value<double> increment = const Value.absent(),
                Value<int> successThreshold = const Value.absent(),
                Value<double> deload = const Value.absent(),
                Value<int> failureThreshold = const Value.absent(),
                Value<int> successStreak = const Value.absent(),
                Value<int> failStreak = const Value.absent(),
              }) => WorkoutItemsCompanion.insert(
                id: id,
                workoutId: workoutId,
                exerciseId: exerciseId,
                position: position,
                targetSets: targetSets,
                repsMin: repsMin,
                repsMax: repsMax,
                toFailure: toFailure,
                restSeconds: restSeconds,
                suggestedWeight: suggestedWeight,
                progression: progression,
                holdSeconds: holdSeconds,
                increment: increment,
                successThreshold: successThreshold,
                deload: deload,
                failureThreshold: failureThreshold,
                successStreak: successStreak,
                failStreak: failStreak,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkoutItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workoutId = false, exerciseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (workoutId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.workoutId,
                                referencedTable: $$WorkoutItemsTableReferences
                                    ._workoutIdTable(db),
                                referencedColumn: $$WorkoutItemsTableReferences
                                    ._workoutIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (exerciseId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.exerciseId,
                                referencedTable: $$WorkoutItemsTableReferences
                                    ._exerciseIdTable(db),
                                referencedColumn: $$WorkoutItemsTableReferences
                                    ._exerciseIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WorkoutItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutItemsTable,
      WorkoutItem,
      $$WorkoutItemsTableFilterComposer,
      $$WorkoutItemsTableOrderingComposer,
      $$WorkoutItemsTableAnnotationComposer,
      $$WorkoutItemsTableCreateCompanionBuilder,
      $$WorkoutItemsTableUpdateCompanionBuilder,
      (WorkoutItem, $$WorkoutItemsTableReferences),
      WorkoutItem,
      PrefetchHooks Function({bool workoutId, bool exerciseId})
    >;
typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      Value<int?> routineId,
      Value<int?> workoutId,
      required String name,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<int> durationSeconds,
      Value<double> totalVolume,
      Value<int> setsCompleted,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      Value<int?> routineId,
      Value<int?> workoutId,
      Value<String> name,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int> durationSeconds,
      Value<double> totalVolume,
      Value<int> setsCompleted,
    });

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SessionSetsTable, List<SessionSet>>
  _sessionSetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessionSets,
    aliasName: 'sessions__id__session_sets__session_id',
  );

  $$SessionSetsTableProcessedTableManager get sessionSetsRefs {
    final manager = $$SessionSetsTableTableManager(
      $_db,
      $_db.sessionSets,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get workoutId => $composableBuilder(
    column: $table.workoutId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalVolume => $composableBuilder(
    column: $table.totalVolume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setsCompleted => $composableBuilder(
    column: $table.setsCompleted,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sessionSetsRefs(
    Expression<bool> Function($$SessionSetsTableFilterComposer f) f,
  ) {
    final $$SessionSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionSets,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionSetsTableFilterComposer(
            $db: $db,
            $table: $db.sessionSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get workoutId => $composableBuilder(
    column: $table.workoutId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalVolume => $composableBuilder(
    column: $table.totalVolume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setsCompleted => $composableBuilder(
    column: $table.setsCompleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get routineId =>
      $composableBuilder(column: $table.routineId, builder: (column) => column);

  GeneratedColumn<int> get workoutId =>
      $composableBuilder(column: $table.workoutId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalVolume => $composableBuilder(
    column: $table.totalVolume,
    builder: (column) => column,
  );

  GeneratedColumn<int> get setsCompleted => $composableBuilder(
    column: $table.setsCompleted,
    builder: (column) => column,
  );

  Expression<T> sessionSetsRefs<T extends Object>(
    Expression<T> Function($$SessionSetsTableAnnotationComposer a) f,
  ) {
    final $$SessionSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionSets,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, $$SessionsTableReferences),
          Session,
          PrefetchHooks Function({bool sessionSetsRefs})
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> routineId = const Value.absent(),
                Value<int?> workoutId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<double> totalVolume = const Value.absent(),
                Value<int> setsCompleted = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                routineId: routineId,
                workoutId: workoutId,
                name: name,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                totalVolume: totalVolume,
                setsCompleted: setsCompleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> routineId = const Value.absent(),
                Value<int?> workoutId = const Value.absent(),
                required String name,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<double> totalVolume = const Value.absent(),
                Value<int> setsCompleted = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                routineId: routineId,
                workoutId: workoutId,
                name: name,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                totalVolume: totalVolume,
                setsCompleted: setsCompleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionSetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (sessionSetsRefs) db.sessionSets],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionSetsRefs)
                    await $_getPrefetchedData<
                      Session,
                      $SessionsTable,
                      SessionSet
                    >(
                      currentTable: table,
                      referencedTable: $$SessionsTableReferences
                          ._sessionSetsRefsTable(db),
                      managerFromTypedResult: (p0) => $$SessionsTableReferences(
                        db,
                        table,
                        p0,
                      ).sessionSetsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, $$SessionsTableReferences),
      Session,
      PrefetchHooks Function({bool sessionSetsRefs})
    >;
typedef $$SessionSetsTableCreateCompanionBuilder =
    SessionSetsCompanion Function({
      Value<int> id,
      required int sessionId,
      Value<int?> exerciseId,
      required String exerciseName,
      required int setNumber,
      Value<double> weight,
      Value<int> reps,
      Value<bool> done,
      Value<int> goalReps,
      Value<double?> goalWeight,
      Value<int?> seconds,
      Value<int?> goalSeconds,
    });
typedef $$SessionSetsTableUpdateCompanionBuilder =
    SessionSetsCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<int?> exerciseId,
      Value<String> exerciseName,
      Value<int> setNumber,
      Value<double> weight,
      Value<int> reps,
      Value<bool> done,
      Value<int> goalReps,
      Value<double?> goalWeight,
      Value<int?> seconds,
      Value<int?> goalSeconds,
    });

final class $$SessionSetsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionSetsTable, SessionSet> {
  $$SessionSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias('session_sets__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SessionSetsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionSetsTable> {
  $$SessionSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setNumber => $composableBuilder(
    column: $table.setNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goalReps => $composableBuilder(
    column: $table.goalReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get goalWeight => $composableBuilder(
    column: $table.goalWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seconds => $composableBuilder(
    column: $table.seconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goalSeconds => $composableBuilder(
    column: $table.goalSeconds,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionSetsTable> {
  $$SessionSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setNumber => $composableBuilder(
    column: $table.setNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goalReps => $composableBuilder(
    column: $table.goalReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get goalWeight => $composableBuilder(
    column: $table.goalWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seconds => $composableBuilder(
    column: $table.seconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goalSeconds => $composableBuilder(
    column: $table.goalSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionSetsTable> {
  $$SessionSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get setNumber =>
      $composableBuilder(column: $table.setNumber, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<int> get goalReps =>
      $composableBuilder(column: $table.goalReps, builder: (column) => column);

  GeneratedColumn<double> get goalWeight => $composableBuilder(
    column: $table.goalWeight,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seconds =>
      $composableBuilder(column: $table.seconds, builder: (column) => column);

  GeneratedColumn<int> get goalSeconds => $composableBuilder(
    column: $table.goalSeconds,
    builder: (column) => column,
  );

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionSetsTable,
          SessionSet,
          $$SessionSetsTableFilterComposer,
          $$SessionSetsTableOrderingComposer,
          $$SessionSetsTableAnnotationComposer,
          $$SessionSetsTableCreateCompanionBuilder,
          $$SessionSetsTableUpdateCompanionBuilder,
          (SessionSet, $$SessionSetsTableReferences),
          SessionSet,
          PrefetchHooks Function({bool sessionId})
        > {
  $$SessionSetsTableTableManager(_$AppDatabase db, $SessionSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<int?> exerciseId = const Value.absent(),
                Value<String> exerciseName = const Value.absent(),
                Value<int> setNumber = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> goalReps = const Value.absent(),
                Value<double?> goalWeight = const Value.absent(),
                Value<int?> seconds = const Value.absent(),
                Value<int?> goalSeconds = const Value.absent(),
              }) => SessionSetsCompanion(
                id: id,
                sessionId: sessionId,
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                setNumber: setNumber,
                weight: weight,
                reps: reps,
                done: done,
                goalReps: goalReps,
                goalWeight: goalWeight,
                seconds: seconds,
                goalSeconds: goalSeconds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                Value<int?> exerciseId = const Value.absent(),
                required String exerciseName,
                required int setNumber,
                Value<double> weight = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> goalReps = const Value.absent(),
                Value<double?> goalWeight = const Value.absent(),
                Value<int?> seconds = const Value.absent(),
                Value<int?> goalSeconds = const Value.absent(),
              }) => SessionSetsCompanion.insert(
                id: id,
                sessionId: sessionId,
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                setNumber: setNumber,
                weight: weight,
                reps: reps,
                done: done,
                goalReps: goalReps,
                goalWeight: goalWeight,
                seconds: seconds,
                goalSeconds: goalSeconds,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$SessionSetsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$SessionSetsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SessionSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionSetsTable,
      SessionSet,
      $$SessionSetsTableFilterComposer,
      $$SessionSetsTableOrderingComposer,
      $$SessionSetsTableAnnotationComposer,
      $$SessionSetsTableCreateCompanionBuilder,
      $$SessionSetsTableUpdateCompanionBuilder,
      (SessionSet, $$SessionSetsTableReferences),
      SessionSet,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      Value<String> weightUnit,
      Value<int?> activeRoutineId,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      Value<String> weightUnit,
      Value<int?> activeRoutineId,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weightUnit => $composableBuilder(
    column: $table.weightUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activeRoutineId => $composableBuilder(
    column: $table.activeRoutineId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weightUnit => $composableBuilder(
    column: $table.weightUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activeRoutineId => $composableBuilder(
    column: $table.activeRoutineId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get weightUnit => $composableBuilder(
    column: $table.weightUnit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get activeRoutineId => $composableBuilder(
    column: $table.activeRoutineId,
    builder: (column) => column,
  );
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> weightUnit = const Value.absent(),
                Value<int?> activeRoutineId = const Value.absent(),
              }) => SettingsCompanion(
                id: id,
                weightUnit: weightUnit,
                activeRoutineId: activeRoutineId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> weightUnit = const Value.absent(),
                Value<int?> activeRoutineId = const Value.absent(),
              }) => SettingsCompanion.insert(
                id: id,
                weightUnit: weightUnit,
                activeRoutineId: activeRoutineId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db, _db.exercises);
  $$RoutinesTableTableManager get routines =>
      $$RoutinesTableTableManager(_db, _db.routines);
  $$WorkoutsTableTableManager get workouts =>
      $$WorkoutsTableTableManager(_db, _db.workouts);
  $$WorkoutItemsTableTableManager get workoutItems =>
      $$WorkoutItemsTableTableManager(_db, _db.workoutItems);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$SessionSetsTableTableManager get sessionSets =>
      $$SessionSetsTableTableManager(_db, _db.sessionSets);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
