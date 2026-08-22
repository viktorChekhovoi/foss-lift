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
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seedKeyMeta = const VerificationMeta(
    'seedKey',
  );
  @override
  late final GeneratedColumn<String> seedKey = GeneratedColumn<String>(
    'seed_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  late final GeneratedColumnWithTypeConverter<ExerciseMeasure, String> measure =
      GeneratedColumn<String>(
        'measure',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('reps'),
      ).withConverter<ExerciseMeasure>($ExercisesTable.$convertermeasure);
  @override
  late final GeneratedColumnWithTypeConverter<WeightType, String> weightType =
      GeneratedColumn<String>(
        'weight_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('machine'),
      ).withConverter<WeightType>($ExercisesTable.$converterweightType);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 300),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barWeightMeta = const VerificationMeta(
    'barWeight',
  );
  @override
  late final GeneratedColumn<double> barWeight = GeneratedColumn<double>(
    'bar_weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extraPrimaryGroupsMeta =
      const VerificationMeta('extraPrimaryGroups');
  @override
  late final GeneratedColumn<String> extraPrimaryGroups =
      GeneratedColumn<String>(
        'extra_primary_groups',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _secondaryGroupsMeta = const VerificationMeta(
    'secondaryGroups',
  );
  @override
  late final GeneratedColumn<String> secondaryGroups = GeneratedColumn<String>(
    'secondary_groups',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _unitOverrideMeta = const VerificationMeta(
    'unitOverride',
  );
  @override
  late final GeneratedColumn<String> unitOverride = GeneratedColumn<String>(
    'unit_override',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _warmupSetsMeta = const VerificationMeta(
    'warmupSets',
  );
  @override
  late final GeneratedColumn<int> warmupSets = GeneratedColumn<int>(
    'warmup_sets',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    seedKey,
    muscleGroup,
    equipment,
    videoUrl,
    isCustom,
    measure,
    weightType,
    notes,
    barWeight,
    extraPrimaryGroups,
    secondaryGroups,
    unitOverride,
    warmupSets,
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
    if (data.containsKey('seed_key')) {
      context.handle(
        _seedKeyMeta,
        seedKey.isAcceptableOrUnknown(data['seed_key']!, _seedKeyMeta),
      );
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
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('bar_weight')) {
      context.handle(
        _barWeightMeta,
        barWeight.isAcceptableOrUnknown(data['bar_weight']!, _barWeightMeta),
      );
    }
    if (data.containsKey('extra_primary_groups')) {
      context.handle(
        _extraPrimaryGroupsMeta,
        extraPrimaryGroups.isAcceptableOrUnknown(
          data['extra_primary_groups']!,
          _extraPrimaryGroupsMeta,
        ),
      );
    }
    if (data.containsKey('secondary_groups')) {
      context.handle(
        _secondaryGroupsMeta,
        secondaryGroups.isAcceptableOrUnknown(
          data['secondary_groups']!,
          _secondaryGroupsMeta,
        ),
      );
    }
    if (data.containsKey('unit_override')) {
      context.handle(
        _unitOverrideMeta,
        unitOverride.isAcceptableOrUnknown(
          data['unit_override']!,
          _unitOverrideMeta,
        ),
      );
    }
    if (data.containsKey('warmup_sets')) {
      context.handle(
        _warmupSetsMeta,
        warmupSets.isAcceptableOrUnknown(data['warmup_sets']!, _warmupSetsMeta),
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
      seedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seed_key'],
      ),
      muscleGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}muscle_group'],
      )!,
      equipment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipment'],
      )!,
      videoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_url'],
      ),
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      measure: $ExercisesTable.$convertermeasure.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}measure'],
        )!,
      ),
      weightType: $ExercisesTable.$converterweightType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}weight_type'],
        )!,
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      barWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bar_weight'],
      ),
      extraPrimaryGroups: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra_primary_groups'],
      )!,
      secondaryGroups: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_groups'],
      )!,
      unitOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_override'],
      ),
      warmupSets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}warmup_sets'],
      ),
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ExerciseMeasure, String, String> $convertermeasure =
      const EnumNameConverter<ExerciseMeasure>(ExerciseMeasure.values);
  static JsonTypeConverter2<WeightType, String, String> $converterweightType =
      const EnumNameConverter<WeightType>(WeightType.values);
}

class Exercise extends DataClass implements Insertable<Exercise> {
  final int id;

  /// Canonical English name used by history and routine codes.
  final String name;

  /// Starter-library key, or null for a user-created exercise.
  final String? seedKey;

  /// Lead muscle group used for filing and ordering exercises.
  final String muscleGroup;
  final String equipment;
  final String? videoUrl;
  final bool isCustom;

  /// Whether the movement is counted in reps or held for time.
  final ExerciseMeasure measure;

  /// How the movement is loaded, determining the meaning of its weight.
  final WeightType weightType;

  /// Personal gym note, excluded from shared routine codes.
  final String? notes;

  /// Exercise-specific bar weight in kg, or null for the configured default.
  final double? barWeight;

  /// Additional primary groups, joined by [kGroupSeparator].
  final String extraPrimaryGroups;

  /// Secondary muscle groups, joined by [kGroupSeparator].
  final String secondaryGroups;

  /// Display-unit override for this movement, or null for the app unit.
  final String? unitOverride;

  /// Exercise-specific warm-up count; null follows `Settings.warmupSets`.
  final int? warmupSets;
  const Exercise({
    required this.id,
    required this.name,
    this.seedKey,
    required this.muscleGroup,
    required this.equipment,
    this.videoUrl,
    required this.isCustom,
    required this.measure,
    required this.weightType,
    this.notes,
    this.barWeight,
    required this.extraPrimaryGroups,
    required this.secondaryGroups,
    this.unitOverride,
    this.warmupSets,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || seedKey != null) {
      map['seed_key'] = Variable<String>(seedKey);
    }
    map['muscle_group'] = Variable<String>(muscleGroup);
    map['equipment'] = Variable<String>(equipment);
    if (!nullToAbsent || videoUrl != null) {
      map['video_url'] = Variable<String>(videoUrl);
    }
    map['is_custom'] = Variable<bool>(isCustom);
    {
      map['measure'] = Variable<String>(
        $ExercisesTable.$convertermeasure.toSql(measure),
      );
    }
    {
      map['weight_type'] = Variable<String>(
        $ExercisesTable.$converterweightType.toSql(weightType),
      );
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || barWeight != null) {
      map['bar_weight'] = Variable<double>(barWeight);
    }
    map['extra_primary_groups'] = Variable<String>(extraPrimaryGroups);
    map['secondary_groups'] = Variable<String>(secondaryGroups);
    if (!nullToAbsent || unitOverride != null) {
      map['unit_override'] = Variable<String>(unitOverride);
    }
    if (!nullToAbsent || warmupSets != null) {
      map['warmup_sets'] = Variable<int>(warmupSets);
    }
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      name: Value(name),
      seedKey: seedKey == null && nullToAbsent
          ? const Value.absent()
          : Value(seedKey),
      muscleGroup: Value(muscleGroup),
      equipment: Value(equipment),
      videoUrl: videoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(videoUrl),
      isCustom: Value(isCustom),
      measure: Value(measure),
      weightType: Value(weightType),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      barWeight: barWeight == null && nullToAbsent
          ? const Value.absent()
          : Value(barWeight),
      extraPrimaryGroups: Value(extraPrimaryGroups),
      secondaryGroups: Value(secondaryGroups),
      unitOverride: unitOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(unitOverride),
      warmupSets: warmupSets == null && nullToAbsent
          ? const Value.absent()
          : Value(warmupSets),
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
      seedKey: serializer.fromJson<String?>(json['seedKey']),
      muscleGroup: serializer.fromJson<String>(json['muscleGroup']),
      equipment: serializer.fromJson<String>(json['equipment']),
      videoUrl: serializer.fromJson<String?>(json['videoUrl']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      measure: $ExercisesTable.$convertermeasure.fromJson(
        serializer.fromJson<String>(json['measure']),
      ),
      weightType: $ExercisesTable.$converterweightType.fromJson(
        serializer.fromJson<String>(json['weightType']),
      ),
      notes: serializer.fromJson<String?>(json['notes']),
      barWeight: serializer.fromJson<double?>(json['barWeight']),
      extraPrimaryGroups: serializer.fromJson<String>(
        json['extraPrimaryGroups'],
      ),
      secondaryGroups: serializer.fromJson<String>(json['secondaryGroups']),
      unitOverride: serializer.fromJson<String?>(json['unitOverride']),
      warmupSets: serializer.fromJson<int?>(json['warmupSets']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'seedKey': serializer.toJson<String?>(seedKey),
      'muscleGroup': serializer.toJson<String>(muscleGroup),
      'equipment': serializer.toJson<String>(equipment),
      'videoUrl': serializer.toJson<String?>(videoUrl),
      'isCustom': serializer.toJson<bool>(isCustom),
      'measure': serializer.toJson<String>(
        $ExercisesTable.$convertermeasure.toJson(measure),
      ),
      'weightType': serializer.toJson<String>(
        $ExercisesTable.$converterweightType.toJson(weightType),
      ),
      'notes': serializer.toJson<String?>(notes),
      'barWeight': serializer.toJson<double?>(barWeight),
      'extraPrimaryGroups': serializer.toJson<String>(extraPrimaryGroups),
      'secondaryGroups': serializer.toJson<String>(secondaryGroups),
      'unitOverride': serializer.toJson<String?>(unitOverride),
      'warmupSets': serializer.toJson<int?>(warmupSets),
    };
  }

  Exercise copyWith({
    int? id,
    String? name,
    Value<String?> seedKey = const Value.absent(),
    String? muscleGroup,
    String? equipment,
    Value<String?> videoUrl = const Value.absent(),
    bool? isCustom,
    ExerciseMeasure? measure,
    WeightType? weightType,
    Value<String?> notes = const Value.absent(),
    Value<double?> barWeight = const Value.absent(),
    String? extraPrimaryGroups,
    String? secondaryGroups,
    Value<String?> unitOverride = const Value.absent(),
    Value<int?> warmupSets = const Value.absent(),
  }) => Exercise(
    id: id ?? this.id,
    name: name ?? this.name,
    seedKey: seedKey.present ? seedKey.value : this.seedKey,
    muscleGroup: muscleGroup ?? this.muscleGroup,
    equipment: equipment ?? this.equipment,
    videoUrl: videoUrl.present ? videoUrl.value : this.videoUrl,
    isCustom: isCustom ?? this.isCustom,
    measure: measure ?? this.measure,
    weightType: weightType ?? this.weightType,
    notes: notes.present ? notes.value : this.notes,
    barWeight: barWeight.present ? barWeight.value : this.barWeight,
    extraPrimaryGroups: extraPrimaryGroups ?? this.extraPrimaryGroups,
    secondaryGroups: secondaryGroups ?? this.secondaryGroups,
    unitOverride: unitOverride.present ? unitOverride.value : this.unitOverride,
    warmupSets: warmupSets.present ? warmupSets.value : this.warmupSets,
  );
  Exercise copyWithCompanion(ExercisesCompanion data) {
    return Exercise(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      seedKey: data.seedKey.present ? data.seedKey.value : this.seedKey,
      muscleGroup: data.muscleGroup.present
          ? data.muscleGroup.value
          : this.muscleGroup,
      equipment: data.equipment.present ? data.equipment.value : this.equipment,
      videoUrl: data.videoUrl.present ? data.videoUrl.value : this.videoUrl,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      measure: data.measure.present ? data.measure.value : this.measure,
      weightType: data.weightType.present
          ? data.weightType.value
          : this.weightType,
      notes: data.notes.present ? data.notes.value : this.notes,
      barWeight: data.barWeight.present ? data.barWeight.value : this.barWeight,
      extraPrimaryGroups: data.extraPrimaryGroups.present
          ? data.extraPrimaryGroups.value
          : this.extraPrimaryGroups,
      secondaryGroups: data.secondaryGroups.present
          ? data.secondaryGroups.value
          : this.secondaryGroups,
      unitOverride: data.unitOverride.present
          ? data.unitOverride.value
          : this.unitOverride,
      warmupSets: data.warmupSets.present
          ? data.warmupSets.value
          : this.warmupSets,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Exercise(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('seedKey: $seedKey, ')
          ..write('muscleGroup: $muscleGroup, ')
          ..write('equipment: $equipment, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('isCustom: $isCustom, ')
          ..write('measure: $measure, ')
          ..write('weightType: $weightType, ')
          ..write('notes: $notes, ')
          ..write('barWeight: $barWeight, ')
          ..write('extraPrimaryGroups: $extraPrimaryGroups, ')
          ..write('secondaryGroups: $secondaryGroups, ')
          ..write('unitOverride: $unitOverride, ')
          ..write('warmupSets: $warmupSets')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    seedKey,
    muscleGroup,
    equipment,
    videoUrl,
    isCustom,
    measure,
    weightType,
    notes,
    barWeight,
    extraPrimaryGroups,
    secondaryGroups,
    unitOverride,
    warmupSets,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exercise &&
          other.id == this.id &&
          other.name == this.name &&
          other.seedKey == this.seedKey &&
          other.muscleGroup == this.muscleGroup &&
          other.equipment == this.equipment &&
          other.videoUrl == this.videoUrl &&
          other.isCustom == this.isCustom &&
          other.measure == this.measure &&
          other.weightType == this.weightType &&
          other.notes == this.notes &&
          other.barWeight == this.barWeight &&
          other.extraPrimaryGroups == this.extraPrimaryGroups &&
          other.secondaryGroups == this.secondaryGroups &&
          other.unitOverride == this.unitOverride &&
          other.warmupSets == this.warmupSets);
}

class ExercisesCompanion extends UpdateCompanion<Exercise> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> seedKey;
  final Value<String> muscleGroup;
  final Value<String> equipment;
  final Value<String?> videoUrl;
  final Value<bool> isCustom;
  final Value<ExerciseMeasure> measure;
  final Value<WeightType> weightType;
  final Value<String?> notes;
  final Value<double?> barWeight;
  final Value<String> extraPrimaryGroups;
  final Value<String> secondaryGroups;
  final Value<String?> unitOverride;
  final Value<int?> warmupSets;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.seedKey = const Value.absent(),
    this.muscleGroup = const Value.absent(),
    this.equipment = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.measure = const Value.absent(),
    this.weightType = const Value.absent(),
    this.notes = const Value.absent(),
    this.barWeight = const Value.absent(),
    this.extraPrimaryGroups = const Value.absent(),
    this.secondaryGroups = const Value.absent(),
    this.unitOverride = const Value.absent(),
    this.warmupSets = const Value.absent(),
  });
  ExercisesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.seedKey = const Value.absent(),
    this.muscleGroup = const Value.absent(),
    this.equipment = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.measure = const Value.absent(),
    this.weightType = const Value.absent(),
    this.notes = const Value.absent(),
    this.barWeight = const Value.absent(),
    this.extraPrimaryGroups = const Value.absent(),
    this.secondaryGroups = const Value.absent(),
    this.unitOverride = const Value.absent(),
    this.warmupSets = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Exercise> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? seedKey,
    Expression<String>? muscleGroup,
    Expression<String>? equipment,
    Expression<String>? videoUrl,
    Expression<bool>? isCustom,
    Expression<String>? measure,
    Expression<String>? weightType,
    Expression<String>? notes,
    Expression<double>? barWeight,
    Expression<String>? extraPrimaryGroups,
    Expression<String>? secondaryGroups,
    Expression<String>? unitOverride,
    Expression<int>? warmupSets,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (seedKey != null) 'seed_key': seedKey,
      if (muscleGroup != null) 'muscle_group': muscleGroup,
      if (equipment != null) 'equipment': equipment,
      if (videoUrl != null) 'video_url': videoUrl,
      if (isCustom != null) 'is_custom': isCustom,
      if (measure != null) 'measure': measure,
      if (weightType != null) 'weight_type': weightType,
      if (notes != null) 'notes': notes,
      if (barWeight != null) 'bar_weight': barWeight,
      if (extraPrimaryGroups != null)
        'extra_primary_groups': extraPrimaryGroups,
      if (secondaryGroups != null) 'secondary_groups': secondaryGroups,
      if (unitOverride != null) 'unit_override': unitOverride,
      if (warmupSets != null) 'warmup_sets': warmupSets,
    });
  }

  ExercisesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? seedKey,
    Value<String>? muscleGroup,
    Value<String>? equipment,
    Value<String?>? videoUrl,
    Value<bool>? isCustom,
    Value<ExerciseMeasure>? measure,
    Value<WeightType>? weightType,
    Value<String?>? notes,
    Value<double?>? barWeight,
    Value<String>? extraPrimaryGroups,
    Value<String>? secondaryGroups,
    Value<String?>? unitOverride,
    Value<int?>? warmupSets,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      seedKey: seedKey ?? this.seedKey,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      videoUrl: videoUrl ?? this.videoUrl,
      isCustom: isCustom ?? this.isCustom,
      measure: measure ?? this.measure,
      weightType: weightType ?? this.weightType,
      notes: notes ?? this.notes,
      barWeight: barWeight ?? this.barWeight,
      extraPrimaryGroups: extraPrimaryGroups ?? this.extraPrimaryGroups,
      secondaryGroups: secondaryGroups ?? this.secondaryGroups,
      unitOverride: unitOverride ?? this.unitOverride,
      warmupSets: warmupSets ?? this.warmupSets,
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
    if (seedKey.present) {
      map['seed_key'] = Variable<String>(seedKey.value);
    }
    if (muscleGroup.present) {
      map['muscle_group'] = Variable<String>(muscleGroup.value);
    }
    if (equipment.present) {
      map['equipment'] = Variable<String>(equipment.value);
    }
    if (videoUrl.present) {
      map['video_url'] = Variable<String>(videoUrl.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (measure.present) {
      map['measure'] = Variable<String>(
        $ExercisesTable.$convertermeasure.toSql(measure.value),
      );
    }
    if (weightType.present) {
      map['weight_type'] = Variable<String>(
        $ExercisesTable.$converterweightType.toSql(weightType.value),
      );
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (barWeight.present) {
      map['bar_weight'] = Variable<double>(barWeight.value);
    }
    if (extraPrimaryGroups.present) {
      map['extra_primary_groups'] = Variable<String>(extraPrimaryGroups.value);
    }
    if (secondaryGroups.present) {
      map['secondary_groups'] = Variable<String>(secondaryGroups.value);
    }
    if (unitOverride.present) {
      map['unit_override'] = Variable<String>(unitOverride.value);
    }
    if (warmupSets.present) {
      map['warmup_sets'] = Variable<int>(warmupSets.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('seedKey: $seedKey, ')
          ..write('muscleGroup: $muscleGroup, ')
          ..write('equipment: $equipment, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('isCustom: $isCustom, ')
          ..write('measure: $measure, ')
          ..write('weightType: $weightType, ')
          ..write('notes: $notes, ')
          ..write('barWeight: $barWeight, ')
          ..write('extraPrimaryGroups: $extraPrimaryGroups, ')
          ..write('secondaryGroups: $secondaryGroups, ')
          ..write('unitOverride: $unitOverride, ')
          ..write('warmupSets: $warmupSets')
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
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seedKeyMeta = const VerificationMeta(
    'seedKey',
  );
  @override
  late final GeneratedColumn<String> seedKey = GeneratedColumn<String>(
    'seed_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _scheduleDaysMeta = const VerificationMeta(
    'scheduleDays',
  );
  @override
  late final GeneratedColumn<int> scheduleDays = GeneratedColumn<int>(
    'schedule_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kNoScheduleMask),
  );
  static const VerificationMeta _reminderMinutesMeta = const VerificationMeta(
    'reminderMinutes',
  );
  @override
  late final GeneratedColumn<int> reminderMinutes = GeneratedColumn<int>(
    'reminder_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    seedKey,
    colorHex,
    position,
    restSeconds,
    scheduleDays,
    reminderMinutes,
    description,
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
    if (data.containsKey('seed_key')) {
      context.handle(
        _seedKeyMeta,
        seedKey.isAcceptableOrUnknown(data['seed_key']!, _seedKeyMeta),
      );
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
    if (data.containsKey('schedule_days')) {
      context.handle(
        _scheduleDaysMeta,
        scheduleDays.isAcceptableOrUnknown(
          data['schedule_days']!,
          _scheduleDaysMeta,
        ),
      );
    }
    if (data.containsKey('reminder_minutes')) {
      context.handle(
        _reminderMinutesMeta,
        reminderMinutes.isAcceptableOrUnknown(
          data['reminder_minutes']!,
          _reminderMinutesMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
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
      seedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seed_key'],
      ),
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
      scheduleDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schedule_days'],
      )!,
      reminderMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
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

  /// Which demo program this is, or null for one of your own.
  ///
  /// Cleared the moment the routine is renamed — a program you have named is
  /// yours, and must not revert to "Push / Pull / Legs" on the next language
  /// switch. See `util/seed_names.dart`.
  final String? seedKey;
  final String colorHex;
  final int position;

  /// Default rest between sets for this routine, in seconds.
  final int restSeconds;

  /// Which weekdays this routine is meant to be trained on, as the bitmask
  /// described in `schedule.dart`. Zero — the default — means no fixed days.
  final int scheduleDays;

  /// Minutes past midnight for the reminder on a scheduled day, or null for no
  /// reminder. Null by default: a notification is something the user asks for,
  /// one routine at a time, not something an offline tracker starts doing.
  final int? reminderMinutes;

  /// What the program is, in a sentence or two — who it is for, how often it is
  /// trained, what it is trying to do. Null on a routine nobody has described,
  /// which is every routine until somebody types one.
  ///
  /// **It travels.** A program the app ships arrives with the description its
  /// author wrote, and a routine of your own carries yours into the code you
  /// share and the backup you take. See `data/routine_code.dart`.
  ///
  /// **Declared last on purpose.** `ALTER TABLE … ADD COLUMN` appends, so an
  /// upgraded database has to end up the same shape as a fresh one.
  final String? description;
  const Routine({
    required this.id,
    required this.name,
    this.seedKey,
    required this.colorHex,
    required this.position,
    required this.restSeconds,
    required this.scheduleDays,
    this.reminderMinutes,
    this.description,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || seedKey != null) {
      map['seed_key'] = Variable<String>(seedKey);
    }
    map['color_hex'] = Variable<String>(colorHex);
    map['position'] = Variable<int>(position);
    map['rest_seconds'] = Variable<int>(restSeconds);
    map['schedule_days'] = Variable<int>(scheduleDays);
    if (!nullToAbsent || reminderMinutes != null) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    return map;
  }

  RoutinesCompanion toCompanion(bool nullToAbsent) {
    return RoutinesCompanion(
      id: Value(id),
      name: Value(name),
      seedKey: seedKey == null && nullToAbsent
          ? const Value.absent()
          : Value(seedKey),
      colorHex: Value(colorHex),
      position: Value(position),
      restSeconds: Value(restSeconds),
      scheduleDays: Value(scheduleDays),
      reminderMinutes: reminderMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinutes),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
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
      seedKey: serializer.fromJson<String?>(json['seedKey']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      position: serializer.fromJson<int>(json['position']),
      restSeconds: serializer.fromJson<int>(json['restSeconds']),
      scheduleDays: serializer.fromJson<int>(json['scheduleDays']),
      reminderMinutes: serializer.fromJson<int?>(json['reminderMinutes']),
      description: serializer.fromJson<String?>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'seedKey': serializer.toJson<String?>(seedKey),
      'colorHex': serializer.toJson<String>(colorHex),
      'position': serializer.toJson<int>(position),
      'restSeconds': serializer.toJson<int>(restSeconds),
      'scheduleDays': serializer.toJson<int>(scheduleDays),
      'reminderMinutes': serializer.toJson<int?>(reminderMinutes),
      'description': serializer.toJson<String?>(description),
    };
  }

  Routine copyWith({
    int? id,
    String? name,
    Value<String?> seedKey = const Value.absent(),
    String? colorHex,
    int? position,
    int? restSeconds,
    int? scheduleDays,
    Value<int?> reminderMinutes = const Value.absent(),
    Value<String?> description = const Value.absent(),
  }) => Routine(
    id: id ?? this.id,
    name: name ?? this.name,
    seedKey: seedKey.present ? seedKey.value : this.seedKey,
    colorHex: colorHex ?? this.colorHex,
    position: position ?? this.position,
    restSeconds: restSeconds ?? this.restSeconds,
    scheduleDays: scheduleDays ?? this.scheduleDays,
    reminderMinutes: reminderMinutes.present
        ? reminderMinutes.value
        : this.reminderMinutes,
    description: description.present ? description.value : this.description,
  );
  Routine copyWithCompanion(RoutinesCompanion data) {
    return Routine(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      seedKey: data.seedKey.present ? data.seedKey.value : this.seedKey,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      position: data.position.present ? data.position.value : this.position,
      restSeconds: data.restSeconds.present
          ? data.restSeconds.value
          : this.restSeconds,
      scheduleDays: data.scheduleDays.present
          ? data.scheduleDays.value
          : this.scheduleDays,
      reminderMinutes: data.reminderMinutes.present
          ? data.reminderMinutes.value
          : this.reminderMinutes,
      description: data.description.present
          ? data.description.value
          : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Routine(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('seedKey: $seedKey, ')
          ..write('colorHex: $colorHex, ')
          ..write('position: $position, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('scheduleDays: $scheduleDays, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    seedKey,
    colorHex,
    position,
    restSeconds,
    scheduleDays,
    reminderMinutes,
    description,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Routine &&
          other.id == this.id &&
          other.name == this.name &&
          other.seedKey == this.seedKey &&
          other.colorHex == this.colorHex &&
          other.position == this.position &&
          other.restSeconds == this.restSeconds &&
          other.scheduleDays == this.scheduleDays &&
          other.reminderMinutes == this.reminderMinutes &&
          other.description == this.description);
}

class RoutinesCompanion extends UpdateCompanion<Routine> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> seedKey;
  final Value<String> colorHex;
  final Value<int> position;
  final Value<int> restSeconds;
  final Value<int> scheduleDays;
  final Value<int?> reminderMinutes;
  final Value<String?> description;
  const RoutinesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.seedKey = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.position = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.scheduleDays = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.description = const Value.absent(),
  });
  RoutinesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.seedKey = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.position = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.scheduleDays = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.description = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Routine> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? seedKey,
    Expression<String>? colorHex,
    Expression<int>? position,
    Expression<int>? restSeconds,
    Expression<int>? scheduleDays,
    Expression<int>? reminderMinutes,
    Expression<String>? description,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (seedKey != null) 'seed_key': seedKey,
      if (colorHex != null) 'color_hex': colorHex,
      if (position != null) 'position': position,
      if (restSeconds != null) 'rest_seconds': restSeconds,
      if (scheduleDays != null) 'schedule_days': scheduleDays,
      if (reminderMinutes != null) 'reminder_minutes': reminderMinutes,
      if (description != null) 'description': description,
    });
  }

  RoutinesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? seedKey,
    Value<String>? colorHex,
    Value<int>? position,
    Value<int>? restSeconds,
    Value<int>? scheduleDays,
    Value<int?>? reminderMinutes,
    Value<String?>? description,
  }) {
    return RoutinesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      seedKey: seedKey ?? this.seedKey,
      colorHex: colorHex ?? this.colorHex,
      position: position ?? this.position,
      restSeconds: restSeconds ?? this.restSeconds,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      description: description ?? this.description,
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
    if (seedKey.present) {
      map['seed_key'] = Variable<String>(seedKey.value);
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
    if (scheduleDays.present) {
      map['schedule_days'] = Variable<int>(scheduleDays.value);
    }
    if (reminderMinutes.present) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutinesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('seedKey: $seedKey, ')
          ..write('colorHex: $colorHex, ')
          ..write('position: $position, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('scheduleDays: $scheduleDays, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('description: $description')
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
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seedKeyMeta = const VerificationMeta(
    'seedKey',
  );
  @override
  late final GeneratedColumn<String> seedKey = GeneratedColumn<String>(
    'seed_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _warmupsEnabledMeta = const VerificationMeta(
    'warmupsEnabled',
  );
  @override
  late final GeneratedColumn<bool> warmupsEnabled = GeneratedColumn<bool>(
    'warmups_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("warmups_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routineId,
    name,
    seedKey,
    position,
    warmupsEnabled,
  ];
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
    if (data.containsKey('seed_key')) {
      context.handle(
        _seedKeyMeta,
        seedKey.isAcceptableOrUnknown(data['seed_key']!, _seedKeyMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('warmups_enabled')) {
      context.handle(
        _warmupsEnabledMeta,
        warmupsEnabled.isAcceptableOrUnknown(
          data['warmups_enabled']!,
          _warmupsEnabledMeta,
        ),
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
      seedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seed_key'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      warmupsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}warmups_enabled'],
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

  /// Which training day of a demo program this is, or null. Cleared on
  /// rename, for the same reason as [Routines.seedKey].
  final String? seedKey;
  final int position;

  /// Whether this day suggests warm-up ramps at all. On unless somebody turns
  /// it off — for the day that follows another, or the one you warm up for
  /// before the app is open. It belongs to the day rather than the session, so
  /// a day trained without ramps opens without them again next week.
  final bool warmupsEnabled;
  const Workout({
    required this.id,
    required this.routineId,
    required this.name,
    this.seedKey,
    required this.position,
    required this.warmupsEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['routine_id'] = Variable<int>(routineId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || seedKey != null) {
      map['seed_key'] = Variable<String>(seedKey);
    }
    map['position'] = Variable<int>(position);
    map['warmups_enabled'] = Variable<bool>(warmupsEnabled);
    return map;
  }

  WorkoutsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutsCompanion(
      id: Value(id),
      routineId: Value(routineId),
      name: Value(name),
      seedKey: seedKey == null && nullToAbsent
          ? const Value.absent()
          : Value(seedKey),
      position: Value(position),
      warmupsEnabled: Value(warmupsEnabled),
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
      seedKey: serializer.fromJson<String?>(json['seedKey']),
      position: serializer.fromJson<int>(json['position']),
      warmupsEnabled: serializer.fromJson<bool>(json['warmupsEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'routineId': serializer.toJson<int>(routineId),
      'name': serializer.toJson<String>(name),
      'seedKey': serializer.toJson<String?>(seedKey),
      'position': serializer.toJson<int>(position),
      'warmupsEnabled': serializer.toJson<bool>(warmupsEnabled),
    };
  }

  Workout copyWith({
    int? id,
    int? routineId,
    String? name,
    Value<String?> seedKey = const Value.absent(),
    int? position,
    bool? warmupsEnabled,
  }) => Workout(
    id: id ?? this.id,
    routineId: routineId ?? this.routineId,
    name: name ?? this.name,
    seedKey: seedKey.present ? seedKey.value : this.seedKey,
    position: position ?? this.position,
    warmupsEnabled: warmupsEnabled ?? this.warmupsEnabled,
  );
  Workout copyWithCompanion(WorkoutsCompanion data) {
    return Workout(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      name: data.name.present ? data.name.value : this.name,
      seedKey: data.seedKey.present ? data.seedKey.value : this.seedKey,
      position: data.position.present ? data.position.value : this.position,
      warmupsEnabled: data.warmupsEnabled.present
          ? data.warmupsEnabled.value
          : this.warmupsEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Workout(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('name: $name, ')
          ..write('seedKey: $seedKey, ')
          ..write('position: $position, ')
          ..write('warmupsEnabled: $warmupsEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, routineId, name, seedKey, position, warmupsEnabled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workout &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.name == this.name &&
          other.seedKey == this.seedKey &&
          other.position == this.position &&
          other.warmupsEnabled == this.warmupsEnabled);
}

class WorkoutsCompanion extends UpdateCompanion<Workout> {
  final Value<int> id;
  final Value<int> routineId;
  final Value<String> name;
  final Value<String?> seedKey;
  final Value<int> position;
  final Value<bool> warmupsEnabled;
  const WorkoutsCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.name = const Value.absent(),
    this.seedKey = const Value.absent(),
    this.position = const Value.absent(),
    this.warmupsEnabled = const Value.absent(),
  });
  WorkoutsCompanion.insert({
    this.id = const Value.absent(),
    required int routineId,
    required String name,
    this.seedKey = const Value.absent(),
    this.position = const Value.absent(),
    this.warmupsEnabled = const Value.absent(),
  }) : routineId = Value(routineId),
       name = Value(name);
  static Insertable<Workout> custom({
    Expression<int>? id,
    Expression<int>? routineId,
    Expression<String>? name,
    Expression<String>? seedKey,
    Expression<int>? position,
    Expression<bool>? warmupsEnabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (name != null) 'name': name,
      if (seedKey != null) 'seed_key': seedKey,
      if (position != null) 'position': position,
      if (warmupsEnabled != null) 'warmups_enabled': warmupsEnabled,
    });
  }

  WorkoutsCompanion copyWith({
    Value<int>? id,
    Value<int>? routineId,
    Value<String>? name,
    Value<String?>? seedKey,
    Value<int>? position,
    Value<bool>? warmupsEnabled,
  }) {
    return WorkoutsCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      name: name ?? this.name,
      seedKey: seedKey ?? this.seedKey,
      position: position ?? this.position,
      warmupsEnabled: warmupsEnabled ?? this.warmupsEnabled,
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
    if (seedKey.present) {
      map['seed_key'] = Variable<String>(seedKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (warmupsEnabled.present) {
      map['warmups_enabled'] = Variable<bool>(warmupsEnabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutsCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('name: $name, ')
          ..write('seedKey: $seedKey, ')
          ..write('position: $position, ')
          ..write('warmupsEnabled: $warmupsEnabled')
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
  late final GeneratedColumnWithTypeConverter<SetScheme, String> scheme =
      GeneratedColumn<String>(
        'scheme',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('flat'),
      ).withConverter<SetScheme>($WorkoutItemsTable.$converterscheme);
  static const VerificationMeta _schemePercentMeta = const VerificationMeta(
    'schemePercent',
  );
  @override
  late final GeneratedColumn<int> schemePercent = GeneratedColumn<int>(
    'scheme_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultSchemePercent),
  );
  static const VerificationMeta _customSetsMeta = const VerificationMeta(
    'customSets',
  );
  @override
  late final GeneratedColumn<String> customSets = GeneratedColumn<String>(
    'custom_sets',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _supersetWithPreviousMeta =
      const VerificationMeta('supersetWithPrevious');
  @override
  late final GeneratedColumn<bool> supersetWithPrevious = GeneratedColumn<bool>(
    'superset_with_previous',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("superset_with_previous" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _addWeightAtTopOfRangeMeta =
      const VerificationMeta('addWeightAtTopOfRange');
  @override
  late final GeneratedColumn<bool> addWeightAtTopOfRange =
      GeneratedColumn<bool>(
        'add_weight_at_top_of_range',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("add_weight_at_top_of_range" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _repsIncrementMeta = const VerificationMeta(
    'repsIncrement',
  );
  @override
  late final GeneratedColumn<double> repsIncrement = GeneratedColumn<double>(
    'reps_increment',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _repsDeloadMeta = const VerificationMeta(
    'repsDeload',
  );
  @override
  late final GeneratedColumn<double> repsDeload = GeneratedColumn<double>(
    'reps_deload',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _repsTargetMeta = const VerificationMeta(
    'repsTarget',
  );
  @override
  late final GeneratedColumn<int> repsTarget = GeneratedColumn<int>(
    'reps_target',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sparedRatesMeta = const VerificationMeta(
    'sparedRates',
  );
  @override
  late final GeneratedColumn<String> sparedRates = GeneratedColumn<String>(
    'spared_rates',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cycleBlocksMeta = const VerificationMeta(
    'cycleBlocks',
  );
  @override
  late final GeneratedColumn<String> cycleBlocks = GeneratedColumn<String>(
    'cycle_blocks',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cyclePositionMeta = const VerificationMeta(
    'cyclePosition',
  );
  @override
  late final GeneratedColumn<int> cyclePosition = GeneratedColumn<int>(
    'cycle_position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cycleNamesMeta = const VerificationMeta(
    'cycleNames',
  );
  @override
  late final GeneratedColumn<String> cycleNames = GeneratedColumn<String>(
    'cycle_names',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetRpeMeta = const VerificationMeta(
    'targetRpe',
  );
  @override
  late final GeneratedColumn<int> targetRpe = GeneratedColumn<int>(
    'target_rpe',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<GzclTier?, String> gzclTier =
      GeneratedColumn<String>(
        'gzcl_tier',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<GzclTier?>($WorkoutItemsTable.$convertergzclTiern);
  static const VerificationMeta _gzclStagesMeta = const VerificationMeta(
    'gzclStages',
  );
  @override
  late final GeneratedColumn<String> gzclStages = GeneratedColumn<String>(
    'gzcl_stages',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gzclStageMeta = const VerificationMeta(
    'gzclStage',
  );
  @override
  late final GeneratedColumn<int> gzclStage = GeneratedColumn<int>(
    'gzcl_stage',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _gzclAmrapTargetMeta = const VerificationMeta(
    'gzclAmrapTarget',
  );
  @override
  late final GeneratedColumn<int> gzclAmrapTarget = GeneratedColumn<int>(
    'gzcl_amrap_target',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(defaultGzclT3AmrapTarget),
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
    scheme,
    schemePercent,
    customSets,
    progression,
    holdSeconds,
    increment,
    successThreshold,
    deload,
    failureThreshold,
    successStreak,
    failStreak,
    supersetWithPrevious,
    addWeightAtTopOfRange,
    repsIncrement,
    repsDeload,
    repsTarget,
    sparedRates,
    cycleBlocks,
    cyclePosition,
    cycleNames,
    targetRpe,
    gzclTier,
    gzclStages,
    gzclStage,
    gzclAmrapTarget,
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
    if (data.containsKey('scheme_percent')) {
      context.handle(
        _schemePercentMeta,
        schemePercent.isAcceptableOrUnknown(
          data['scheme_percent']!,
          _schemePercentMeta,
        ),
      );
    }
    if (data.containsKey('custom_sets')) {
      context.handle(
        _customSetsMeta,
        customSets.isAcceptableOrUnknown(data['custom_sets']!, _customSetsMeta),
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
    if (data.containsKey('superset_with_previous')) {
      context.handle(
        _supersetWithPreviousMeta,
        supersetWithPrevious.isAcceptableOrUnknown(
          data['superset_with_previous']!,
          _supersetWithPreviousMeta,
        ),
      );
    }
    if (data.containsKey('add_weight_at_top_of_range')) {
      context.handle(
        _addWeightAtTopOfRangeMeta,
        addWeightAtTopOfRange.isAcceptableOrUnknown(
          data['add_weight_at_top_of_range']!,
          _addWeightAtTopOfRangeMeta,
        ),
      );
    }
    if (data.containsKey('reps_increment')) {
      context.handle(
        _repsIncrementMeta,
        repsIncrement.isAcceptableOrUnknown(
          data['reps_increment']!,
          _repsIncrementMeta,
        ),
      );
    }
    if (data.containsKey('reps_deload')) {
      context.handle(
        _repsDeloadMeta,
        repsDeload.isAcceptableOrUnknown(data['reps_deload']!, _repsDeloadMeta),
      );
    }
    if (data.containsKey('reps_target')) {
      context.handle(
        _repsTargetMeta,
        repsTarget.isAcceptableOrUnknown(data['reps_target']!, _repsTargetMeta),
      );
    }
    if (data.containsKey('spared_rates')) {
      context.handle(
        _sparedRatesMeta,
        sparedRates.isAcceptableOrUnknown(
          data['spared_rates']!,
          _sparedRatesMeta,
        ),
      );
    }
    if (data.containsKey('cycle_blocks')) {
      context.handle(
        _cycleBlocksMeta,
        cycleBlocks.isAcceptableOrUnknown(
          data['cycle_blocks']!,
          _cycleBlocksMeta,
        ),
      );
    }
    if (data.containsKey('cycle_position')) {
      context.handle(
        _cyclePositionMeta,
        cyclePosition.isAcceptableOrUnknown(
          data['cycle_position']!,
          _cyclePositionMeta,
        ),
      );
    }
    if (data.containsKey('cycle_names')) {
      context.handle(
        _cycleNamesMeta,
        cycleNames.isAcceptableOrUnknown(data['cycle_names']!, _cycleNamesMeta),
      );
    }
    if (data.containsKey('target_rpe')) {
      context.handle(
        _targetRpeMeta,
        targetRpe.isAcceptableOrUnknown(data['target_rpe']!, _targetRpeMeta),
      );
    }
    if (data.containsKey('gzcl_stages')) {
      context.handle(
        _gzclStagesMeta,
        gzclStages.isAcceptableOrUnknown(data['gzcl_stages']!, _gzclStagesMeta),
      );
    }
    if (data.containsKey('gzcl_stage')) {
      context.handle(
        _gzclStageMeta,
        gzclStage.isAcceptableOrUnknown(data['gzcl_stage']!, _gzclStageMeta),
      );
    }
    if (data.containsKey('gzcl_amrap_target')) {
      context.handle(
        _gzclAmrapTargetMeta,
        gzclAmrapTarget.isAcceptableOrUnknown(
          data['gzcl_amrap_target']!,
          _gzclAmrapTargetMeta,
        ),
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
      scheme: $WorkoutItemsTable.$converterscheme.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}scheme'],
        )!,
      ),
      schemePercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheme_percent'],
      )!,
      customSets: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_sets'],
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
      supersetWithPrevious: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}superset_with_previous'],
      )!,
      addWeightAtTopOfRange: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}add_weight_at_top_of_range'],
      )!,
      repsIncrement: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reps_increment'],
      )!,
      repsDeload: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reps_deload'],
      )!,
      repsTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps_target'],
      ),
      sparedRates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spared_rates'],
      ),
      cycleBlocks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycle_blocks'],
      ),
      cyclePosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cycle_position'],
      )!,
      cycleNames: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycle_names'],
      ),
      targetRpe: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_rpe'],
      ),
      gzclTier: $WorkoutItemsTable.$convertergzclTiern.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}gzcl_tier'],
        ),
      ),
      gzclStages: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gzcl_stages'],
      ),
      gzclStage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gzcl_stage'],
      )!,
      gzclAmrapTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gzcl_amrap_target'],
      )!,
    );
  }

  @override
  $WorkoutItemsTable createAlias(String alias) {
    return $WorkoutItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SetScheme, String, String> $converterscheme =
      const EnumNameConverter<SetScheme>(SetScheme.values);
  static JsonTypeConverter2<ProgressionMode, String, String>
  $converterprogression = const EnumNameConverter<ProgressionMode>(
    ProgressionMode.values,
  );
  static JsonTypeConverter2<GzclTier, String, String> $convertergzclTier =
      const EnumNameConverter<GzclTier>(GzclTier.values);
  static JsonTypeConverter2<GzclTier?, String?, String?> $convertergzclTiern =
      JsonTypeConverter2.asNullable($convertergzclTier);
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

  /// The top of every ladder this slot produces — see [SetScheme]. Null on a
  /// movement that carries no load.
  final double? suggestedWeight;
  final SetScheme scheme;

  /// What one rung of a back-off or a ramp moves by, as a whole percentage of
  /// [suggestedWeight]. Ignored by the other two schemes.
  final int schemePercent;

  /// The written-out rows of a [SetScheme.custom] slot, encoded — see
  /// `encodeCustomSets`. Null on every other scheme, and on a custom slot
  /// nobody has filled in yet.
  final String? customSets;

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

  /// Whether this slot is trained together with the slot above it — a superset.
  ///
  /// **A join between neighbours, not a group id.** A superset is exercises done
  /// back to back, which only means anything for slots that sit next to each
  /// other; a group id would let a workout claim that slots one and four are a
  /// group with two and three in between, and no screen could honestly draw
  /// that. Expressed this way the nonsense is unrepresentable, reordering
  /// re-forms the groups by itself, and the only rule to enforce is that the
  /// first slot has nothing above it to join to. See `data/superset.dart`.
  ///
  final bool supersetWithPrevious;

  /// Double progression: take the reps and the load in turn inside [repsMin]
  /// … [repsMax], climbing [repsTarget] to the top of the range and stepping
  /// the load only from there.
  ///
  /// Off unless asked for, and meaningless without both a rep range and the
  /// weight axis — a slot with a fixed count has no range to climb, and the
  /// reps axis already advances the number this would. The flag is kept even
  /// while it means nothing, so taking a rep range off a slot and putting it
  /// back does not quietly rewrite how the slot progresses.
  final bool addWeightAtTopOfRange;

  /// How far [repsTarget] moves on a step up, and how far it drops on a
  /// back-off — the rep half of the rates a slot on the advanced axis carries,
  /// beside [increment] and [deload], which are its weight half. Ignored by
  /// every other axis.
  ///
  /// Reals rather than integers because [increment] is one, and a rep rate that
  /// stored differently would be a second kind of number to read, round and
  /// share for no gain — they are rounded where they are applied.
  final double repsIncrement;
  final double repsDeload;

  /// Where inside [repsMin] … [repsMax] the slot has got to, on the advanced
  /// axis. Null means the bottom of the range, which is where a slot that has
  /// never run the rule — or has just had the load stepped — starts.
  ///
  /// Program state rather than a fact about one session: it is what the next
  /// session is judged against, so it outlives the session that moved it. Read
  /// through [WorkoutItemTarget.goalReps], which holds it inside a range that
  /// may have been edited underneath it.
  final int? repsTarget;

  /// The step and back-off this slot last had on the axes it is *not* on, so
  /// that trying another rule for a session does not cost the numbers set
  /// against the one it came from. Null means none kept — a new slot, or one
  /// that has never been moved.
  ///
  /// Encoded rather than given a column per axis, because the pairs are only
  /// ever read and written as a set and nothing queries them: see
  /// `encodeSparedRates`. The axis in use keeps its rates in [increment] and
  /// [deload] as it always has, and the advanced axis its rep half in
  /// [repsIncrement] and [repsDeload] — this holds what is on none of them.
  ///
  final String? sparedRates;

  /// The weeks this slot rotates through, encoded — see [encodeCycleBlocks].
  /// Null on every slot that does not run a cycle, which is nearly all of them.
  ///
  /// A week is a written-out set of rows exactly like [customSets], so the two
  /// share a grammar; what a cycle adds is that there are several of them and
  /// only one is trained per session. Kept across a switch to another scheme
  /// and back, on the same terms as [customSets]: trying a ramp for a session
  /// must not throw away a cycle somebody wrote out.
  final String? cycleBlocks;

  /// Which week the *next* session of this slot uses — an index into
  /// [cycleBlocks], wrapping.
  ///
  /// Program state, like [repsTarget] and the streaks beside it: it is what the
  /// next session is prescribed from, so it outlives the session that moved it
  /// and it survives a builder edit. It does **not** travel in a routine code —
  /// where the sender had got to is not part of the program.
  ///
  final int cyclePosition;

  /// What this slot's weeks are called, encoded — see [encodeCycleNames]. Null
  /// on every slot whose weeks are still "Week 1", "Week 2", which is most of
  /// them.
  ///
  /// Beside [cycleBlocks] rather than inside it: the row grammar is on phones
  /// and a name can hold any character, so widening that column would mean
  /// every installed cycle re-reading itself against a new parser.
  ///
  /// **Declared last**, because `ALTER TABLE … ADD COLUMN` appends and an
  /// upgraded database has to end up the same shape as a fresh one. Whatever
  /// column comes next goes under this one, and takes this note with it.
  final String? cycleNames;

  /// Optional prescribed effort in tenths (80 is RPE 8).
  final int? targetRpe;

  /// Optional GZCL role and its configurable progression state. These follow
  /// the v16 RPE column so fresh and upgraded databases have the same shape.
  final GzclTier? gzclTier;
  final String? gzclStages;
  final int gzclStage;
  final int gzclAmrapTarget;
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
    required this.scheme,
    required this.schemePercent,
    this.customSets,
    required this.progression,
    required this.holdSeconds,
    required this.increment,
    required this.successThreshold,
    required this.deload,
    required this.failureThreshold,
    required this.successStreak,
    required this.failStreak,
    required this.supersetWithPrevious,
    required this.addWeightAtTopOfRange,
    required this.repsIncrement,
    required this.repsDeload,
    this.repsTarget,
    this.sparedRates,
    this.cycleBlocks,
    required this.cyclePosition,
    this.cycleNames,
    this.targetRpe,
    this.gzclTier,
    this.gzclStages,
    required this.gzclStage,
    required this.gzclAmrapTarget,
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
      map['scheme'] = Variable<String>(
        $WorkoutItemsTable.$converterscheme.toSql(scheme),
      );
    }
    map['scheme_percent'] = Variable<int>(schemePercent);
    if (!nullToAbsent || customSets != null) {
      map['custom_sets'] = Variable<String>(customSets);
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
    map['superset_with_previous'] = Variable<bool>(supersetWithPrevious);
    map['add_weight_at_top_of_range'] = Variable<bool>(addWeightAtTopOfRange);
    map['reps_increment'] = Variable<double>(repsIncrement);
    map['reps_deload'] = Variable<double>(repsDeload);
    if (!nullToAbsent || repsTarget != null) {
      map['reps_target'] = Variable<int>(repsTarget);
    }
    if (!nullToAbsent || sparedRates != null) {
      map['spared_rates'] = Variable<String>(sparedRates);
    }
    if (!nullToAbsent || cycleBlocks != null) {
      map['cycle_blocks'] = Variable<String>(cycleBlocks);
    }
    map['cycle_position'] = Variable<int>(cyclePosition);
    if (!nullToAbsent || cycleNames != null) {
      map['cycle_names'] = Variable<String>(cycleNames);
    }
    if (!nullToAbsent || targetRpe != null) {
      map['target_rpe'] = Variable<int>(targetRpe);
    }
    if (!nullToAbsent || gzclTier != null) {
      map['gzcl_tier'] = Variable<String>(
        $WorkoutItemsTable.$convertergzclTiern.toSql(gzclTier),
      );
    }
    if (!nullToAbsent || gzclStages != null) {
      map['gzcl_stages'] = Variable<String>(gzclStages);
    }
    map['gzcl_stage'] = Variable<int>(gzclStage);
    map['gzcl_amrap_target'] = Variable<int>(gzclAmrapTarget);
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
      scheme: Value(scheme),
      schemePercent: Value(schemePercent),
      customSets: customSets == null && nullToAbsent
          ? const Value.absent()
          : Value(customSets),
      progression: Value(progression),
      holdSeconds: Value(holdSeconds),
      increment: Value(increment),
      successThreshold: Value(successThreshold),
      deload: Value(deload),
      failureThreshold: Value(failureThreshold),
      successStreak: Value(successStreak),
      failStreak: Value(failStreak),
      supersetWithPrevious: Value(supersetWithPrevious),
      addWeightAtTopOfRange: Value(addWeightAtTopOfRange),
      repsIncrement: Value(repsIncrement),
      repsDeload: Value(repsDeload),
      repsTarget: repsTarget == null && nullToAbsent
          ? const Value.absent()
          : Value(repsTarget),
      sparedRates: sparedRates == null && nullToAbsent
          ? const Value.absent()
          : Value(sparedRates),
      cycleBlocks: cycleBlocks == null && nullToAbsent
          ? const Value.absent()
          : Value(cycleBlocks),
      cyclePosition: Value(cyclePosition),
      cycleNames: cycleNames == null && nullToAbsent
          ? const Value.absent()
          : Value(cycleNames),
      targetRpe: targetRpe == null && nullToAbsent
          ? const Value.absent()
          : Value(targetRpe),
      gzclTier: gzclTier == null && nullToAbsent
          ? const Value.absent()
          : Value(gzclTier),
      gzclStages: gzclStages == null && nullToAbsent
          ? const Value.absent()
          : Value(gzclStages),
      gzclStage: Value(gzclStage),
      gzclAmrapTarget: Value(gzclAmrapTarget),
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
      scheme: $WorkoutItemsTable.$converterscheme.fromJson(
        serializer.fromJson<String>(json['scheme']),
      ),
      schemePercent: serializer.fromJson<int>(json['schemePercent']),
      customSets: serializer.fromJson<String?>(json['customSets']),
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
      supersetWithPrevious: serializer.fromJson<bool>(
        json['supersetWithPrevious'],
      ),
      addWeightAtTopOfRange: serializer.fromJson<bool>(
        json['addWeightAtTopOfRange'],
      ),
      repsIncrement: serializer.fromJson<double>(json['repsIncrement']),
      repsDeload: serializer.fromJson<double>(json['repsDeload']),
      repsTarget: serializer.fromJson<int?>(json['repsTarget']),
      sparedRates: serializer.fromJson<String?>(json['sparedRates']),
      cycleBlocks: serializer.fromJson<String?>(json['cycleBlocks']),
      cyclePosition: serializer.fromJson<int>(json['cyclePosition']),
      cycleNames: serializer.fromJson<String?>(json['cycleNames']),
      targetRpe: serializer.fromJson<int?>(json['targetRpe']),
      gzclTier: $WorkoutItemsTable.$convertergzclTiern.fromJson(
        serializer.fromJson<String?>(json['gzclTier']),
      ),
      gzclStages: serializer.fromJson<String?>(json['gzclStages']),
      gzclStage: serializer.fromJson<int>(json['gzclStage']),
      gzclAmrapTarget: serializer.fromJson<int>(json['gzclAmrapTarget']),
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
      'scheme': serializer.toJson<String>(
        $WorkoutItemsTable.$converterscheme.toJson(scheme),
      ),
      'schemePercent': serializer.toJson<int>(schemePercent),
      'customSets': serializer.toJson<String?>(customSets),
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
      'supersetWithPrevious': serializer.toJson<bool>(supersetWithPrevious),
      'addWeightAtTopOfRange': serializer.toJson<bool>(addWeightAtTopOfRange),
      'repsIncrement': serializer.toJson<double>(repsIncrement),
      'repsDeload': serializer.toJson<double>(repsDeload),
      'repsTarget': serializer.toJson<int?>(repsTarget),
      'sparedRates': serializer.toJson<String?>(sparedRates),
      'cycleBlocks': serializer.toJson<String?>(cycleBlocks),
      'cyclePosition': serializer.toJson<int>(cyclePosition),
      'cycleNames': serializer.toJson<String?>(cycleNames),
      'targetRpe': serializer.toJson<int?>(targetRpe),
      'gzclTier': serializer.toJson<String?>(
        $WorkoutItemsTable.$convertergzclTiern.toJson(gzclTier),
      ),
      'gzclStages': serializer.toJson<String?>(gzclStages),
      'gzclStage': serializer.toJson<int>(gzclStage),
      'gzclAmrapTarget': serializer.toJson<int>(gzclAmrapTarget),
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
    SetScheme? scheme,
    int? schemePercent,
    Value<String?> customSets = const Value.absent(),
    ProgressionMode? progression,
    int? holdSeconds,
    double? increment,
    int? successThreshold,
    double? deload,
    int? failureThreshold,
    int? successStreak,
    int? failStreak,
    bool? supersetWithPrevious,
    bool? addWeightAtTopOfRange,
    double? repsIncrement,
    double? repsDeload,
    Value<int?> repsTarget = const Value.absent(),
    Value<String?> sparedRates = const Value.absent(),
    Value<String?> cycleBlocks = const Value.absent(),
    int? cyclePosition,
    Value<String?> cycleNames = const Value.absent(),
    Value<int?> targetRpe = const Value.absent(),
    Value<GzclTier?> gzclTier = const Value.absent(),
    Value<String?> gzclStages = const Value.absent(),
    int? gzclStage,
    int? gzclAmrapTarget,
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
    scheme: scheme ?? this.scheme,
    schemePercent: schemePercent ?? this.schemePercent,
    customSets: customSets.present ? customSets.value : this.customSets,
    progression: progression ?? this.progression,
    holdSeconds: holdSeconds ?? this.holdSeconds,
    increment: increment ?? this.increment,
    successThreshold: successThreshold ?? this.successThreshold,
    deload: deload ?? this.deload,
    failureThreshold: failureThreshold ?? this.failureThreshold,
    successStreak: successStreak ?? this.successStreak,
    failStreak: failStreak ?? this.failStreak,
    supersetWithPrevious: supersetWithPrevious ?? this.supersetWithPrevious,
    addWeightAtTopOfRange: addWeightAtTopOfRange ?? this.addWeightAtTopOfRange,
    repsIncrement: repsIncrement ?? this.repsIncrement,
    repsDeload: repsDeload ?? this.repsDeload,
    repsTarget: repsTarget.present ? repsTarget.value : this.repsTarget,
    sparedRates: sparedRates.present ? sparedRates.value : this.sparedRates,
    cycleBlocks: cycleBlocks.present ? cycleBlocks.value : this.cycleBlocks,
    cyclePosition: cyclePosition ?? this.cyclePosition,
    cycleNames: cycleNames.present ? cycleNames.value : this.cycleNames,
    targetRpe: targetRpe.present ? targetRpe.value : this.targetRpe,
    gzclTier: gzclTier.present ? gzclTier.value : this.gzclTier,
    gzclStages: gzclStages.present ? gzclStages.value : this.gzclStages,
    gzclStage: gzclStage ?? this.gzclStage,
    gzclAmrapTarget: gzclAmrapTarget ?? this.gzclAmrapTarget,
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
      scheme: data.scheme.present ? data.scheme.value : this.scheme,
      schemePercent: data.schemePercent.present
          ? data.schemePercent.value
          : this.schemePercent,
      customSets: data.customSets.present
          ? data.customSets.value
          : this.customSets,
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
      supersetWithPrevious: data.supersetWithPrevious.present
          ? data.supersetWithPrevious.value
          : this.supersetWithPrevious,
      addWeightAtTopOfRange: data.addWeightAtTopOfRange.present
          ? data.addWeightAtTopOfRange.value
          : this.addWeightAtTopOfRange,
      repsIncrement: data.repsIncrement.present
          ? data.repsIncrement.value
          : this.repsIncrement,
      repsDeload: data.repsDeload.present
          ? data.repsDeload.value
          : this.repsDeload,
      repsTarget: data.repsTarget.present
          ? data.repsTarget.value
          : this.repsTarget,
      sparedRates: data.sparedRates.present
          ? data.sparedRates.value
          : this.sparedRates,
      cycleBlocks: data.cycleBlocks.present
          ? data.cycleBlocks.value
          : this.cycleBlocks,
      cyclePosition: data.cyclePosition.present
          ? data.cyclePosition.value
          : this.cyclePosition,
      cycleNames: data.cycleNames.present
          ? data.cycleNames.value
          : this.cycleNames,
      targetRpe: data.targetRpe.present ? data.targetRpe.value : this.targetRpe,
      gzclTier: data.gzclTier.present ? data.gzclTier.value : this.gzclTier,
      gzclStages: data.gzclStages.present
          ? data.gzclStages.value
          : this.gzclStages,
      gzclStage: data.gzclStage.present ? data.gzclStage.value : this.gzclStage,
      gzclAmrapTarget: data.gzclAmrapTarget.present
          ? data.gzclAmrapTarget.value
          : this.gzclAmrapTarget,
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
          ..write('scheme: $scheme, ')
          ..write('schemePercent: $schemePercent, ')
          ..write('customSets: $customSets, ')
          ..write('progression: $progression, ')
          ..write('holdSeconds: $holdSeconds, ')
          ..write('increment: $increment, ')
          ..write('successThreshold: $successThreshold, ')
          ..write('deload: $deload, ')
          ..write('failureThreshold: $failureThreshold, ')
          ..write('successStreak: $successStreak, ')
          ..write('failStreak: $failStreak, ')
          ..write('supersetWithPrevious: $supersetWithPrevious, ')
          ..write('addWeightAtTopOfRange: $addWeightAtTopOfRange, ')
          ..write('repsIncrement: $repsIncrement, ')
          ..write('repsDeload: $repsDeload, ')
          ..write('repsTarget: $repsTarget, ')
          ..write('sparedRates: $sparedRates, ')
          ..write('cycleBlocks: $cycleBlocks, ')
          ..write('cyclePosition: $cyclePosition, ')
          ..write('cycleNames: $cycleNames, ')
          ..write('targetRpe: $targetRpe, ')
          ..write('gzclTier: $gzclTier, ')
          ..write('gzclStages: $gzclStages, ')
          ..write('gzclStage: $gzclStage, ')
          ..write('gzclAmrapTarget: $gzclAmrapTarget')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
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
    scheme,
    schemePercent,
    customSets,
    progression,
    holdSeconds,
    increment,
    successThreshold,
    deload,
    failureThreshold,
    successStreak,
    failStreak,
    supersetWithPrevious,
    addWeightAtTopOfRange,
    repsIncrement,
    repsDeload,
    repsTarget,
    sparedRates,
    cycleBlocks,
    cyclePosition,
    cycleNames,
    targetRpe,
    gzclTier,
    gzclStages,
    gzclStage,
    gzclAmrapTarget,
  ]);
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
          other.scheme == this.scheme &&
          other.schemePercent == this.schemePercent &&
          other.customSets == this.customSets &&
          other.progression == this.progression &&
          other.holdSeconds == this.holdSeconds &&
          other.increment == this.increment &&
          other.successThreshold == this.successThreshold &&
          other.deload == this.deload &&
          other.failureThreshold == this.failureThreshold &&
          other.successStreak == this.successStreak &&
          other.failStreak == this.failStreak &&
          other.supersetWithPrevious == this.supersetWithPrevious &&
          other.addWeightAtTopOfRange == this.addWeightAtTopOfRange &&
          other.repsIncrement == this.repsIncrement &&
          other.repsDeload == this.repsDeload &&
          other.repsTarget == this.repsTarget &&
          other.sparedRates == this.sparedRates &&
          other.cycleBlocks == this.cycleBlocks &&
          other.cyclePosition == this.cyclePosition &&
          other.cycleNames == this.cycleNames &&
          other.targetRpe == this.targetRpe &&
          other.gzclTier == this.gzclTier &&
          other.gzclStages == this.gzclStages &&
          other.gzclStage == this.gzclStage &&
          other.gzclAmrapTarget == this.gzclAmrapTarget);
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
  final Value<SetScheme> scheme;
  final Value<int> schemePercent;
  final Value<String?> customSets;
  final Value<ProgressionMode> progression;
  final Value<int> holdSeconds;
  final Value<double> increment;
  final Value<int> successThreshold;
  final Value<double> deload;
  final Value<int> failureThreshold;
  final Value<int> successStreak;
  final Value<int> failStreak;
  final Value<bool> supersetWithPrevious;
  final Value<bool> addWeightAtTopOfRange;
  final Value<double> repsIncrement;
  final Value<double> repsDeload;
  final Value<int?> repsTarget;
  final Value<String?> sparedRates;
  final Value<String?> cycleBlocks;
  final Value<int> cyclePosition;
  final Value<String?> cycleNames;
  final Value<int?> targetRpe;
  final Value<GzclTier?> gzclTier;
  final Value<String?> gzclStages;
  final Value<int> gzclStage;
  final Value<int> gzclAmrapTarget;
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
    this.scheme = const Value.absent(),
    this.schemePercent = const Value.absent(),
    this.customSets = const Value.absent(),
    this.progression = const Value.absent(),
    this.holdSeconds = const Value.absent(),
    this.increment = const Value.absent(),
    this.successThreshold = const Value.absent(),
    this.deload = const Value.absent(),
    this.failureThreshold = const Value.absent(),
    this.successStreak = const Value.absent(),
    this.failStreak = const Value.absent(),
    this.supersetWithPrevious = const Value.absent(),
    this.addWeightAtTopOfRange = const Value.absent(),
    this.repsIncrement = const Value.absent(),
    this.repsDeload = const Value.absent(),
    this.repsTarget = const Value.absent(),
    this.sparedRates = const Value.absent(),
    this.cycleBlocks = const Value.absent(),
    this.cyclePosition = const Value.absent(),
    this.cycleNames = const Value.absent(),
    this.targetRpe = const Value.absent(),
    this.gzclTier = const Value.absent(),
    this.gzclStages = const Value.absent(),
    this.gzclStage = const Value.absent(),
    this.gzclAmrapTarget = const Value.absent(),
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
    this.scheme = const Value.absent(),
    this.schemePercent = const Value.absent(),
    this.customSets = const Value.absent(),
    this.progression = const Value.absent(),
    this.holdSeconds = const Value.absent(),
    this.increment = const Value.absent(),
    this.successThreshold = const Value.absent(),
    this.deload = const Value.absent(),
    this.failureThreshold = const Value.absent(),
    this.successStreak = const Value.absent(),
    this.failStreak = const Value.absent(),
    this.supersetWithPrevious = const Value.absent(),
    this.addWeightAtTopOfRange = const Value.absent(),
    this.repsIncrement = const Value.absent(),
    this.repsDeload = const Value.absent(),
    this.repsTarget = const Value.absent(),
    this.sparedRates = const Value.absent(),
    this.cycleBlocks = const Value.absent(),
    this.cyclePosition = const Value.absent(),
    this.cycleNames = const Value.absent(),
    this.targetRpe = const Value.absent(),
    this.gzclTier = const Value.absent(),
    this.gzclStages = const Value.absent(),
    this.gzclStage = const Value.absent(),
    this.gzclAmrapTarget = const Value.absent(),
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
    Expression<String>? scheme,
    Expression<int>? schemePercent,
    Expression<String>? customSets,
    Expression<String>? progression,
    Expression<int>? holdSeconds,
    Expression<double>? increment,
    Expression<int>? successThreshold,
    Expression<double>? deload,
    Expression<int>? failureThreshold,
    Expression<int>? successStreak,
    Expression<int>? failStreak,
    Expression<bool>? supersetWithPrevious,
    Expression<bool>? addWeightAtTopOfRange,
    Expression<double>? repsIncrement,
    Expression<double>? repsDeload,
    Expression<int>? repsTarget,
    Expression<String>? sparedRates,
    Expression<String>? cycleBlocks,
    Expression<int>? cyclePosition,
    Expression<String>? cycleNames,
    Expression<int>? targetRpe,
    Expression<String>? gzclTier,
    Expression<String>? gzclStages,
    Expression<int>? gzclStage,
    Expression<int>? gzclAmrapTarget,
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
      if (scheme != null) 'scheme': scheme,
      if (schemePercent != null) 'scheme_percent': schemePercent,
      if (customSets != null) 'custom_sets': customSets,
      if (progression != null) 'progression': progression,
      if (holdSeconds != null) 'hold_seconds': holdSeconds,
      if (increment != null) 'increment': increment,
      if (successThreshold != null) 'success_threshold': successThreshold,
      if (deload != null) 'deload': deload,
      if (failureThreshold != null) 'failure_threshold': failureThreshold,
      if (successStreak != null) 'success_streak': successStreak,
      if (failStreak != null) 'fail_streak': failStreak,
      if (supersetWithPrevious != null)
        'superset_with_previous': supersetWithPrevious,
      if (addWeightAtTopOfRange != null)
        'add_weight_at_top_of_range': addWeightAtTopOfRange,
      if (repsIncrement != null) 'reps_increment': repsIncrement,
      if (repsDeload != null) 'reps_deload': repsDeload,
      if (repsTarget != null) 'reps_target': repsTarget,
      if (sparedRates != null) 'spared_rates': sparedRates,
      if (cycleBlocks != null) 'cycle_blocks': cycleBlocks,
      if (cyclePosition != null) 'cycle_position': cyclePosition,
      if (cycleNames != null) 'cycle_names': cycleNames,
      if (targetRpe != null) 'target_rpe': targetRpe,
      if (gzclTier != null) 'gzcl_tier': gzclTier,
      if (gzclStages != null) 'gzcl_stages': gzclStages,
      if (gzclStage != null) 'gzcl_stage': gzclStage,
      if (gzclAmrapTarget != null) 'gzcl_amrap_target': gzclAmrapTarget,
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
    Value<SetScheme>? scheme,
    Value<int>? schemePercent,
    Value<String?>? customSets,
    Value<ProgressionMode>? progression,
    Value<int>? holdSeconds,
    Value<double>? increment,
    Value<int>? successThreshold,
    Value<double>? deload,
    Value<int>? failureThreshold,
    Value<int>? successStreak,
    Value<int>? failStreak,
    Value<bool>? supersetWithPrevious,
    Value<bool>? addWeightAtTopOfRange,
    Value<double>? repsIncrement,
    Value<double>? repsDeload,
    Value<int?>? repsTarget,
    Value<String?>? sparedRates,
    Value<String?>? cycleBlocks,
    Value<int>? cyclePosition,
    Value<String?>? cycleNames,
    Value<int?>? targetRpe,
    Value<GzclTier?>? gzclTier,
    Value<String?>? gzclStages,
    Value<int>? gzclStage,
    Value<int>? gzclAmrapTarget,
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
      scheme: scheme ?? this.scheme,
      schemePercent: schemePercent ?? this.schemePercent,
      customSets: customSets ?? this.customSets,
      progression: progression ?? this.progression,
      holdSeconds: holdSeconds ?? this.holdSeconds,
      increment: increment ?? this.increment,
      successThreshold: successThreshold ?? this.successThreshold,
      deload: deload ?? this.deload,
      failureThreshold: failureThreshold ?? this.failureThreshold,
      successStreak: successStreak ?? this.successStreak,
      failStreak: failStreak ?? this.failStreak,
      supersetWithPrevious: supersetWithPrevious ?? this.supersetWithPrevious,
      addWeightAtTopOfRange:
          addWeightAtTopOfRange ?? this.addWeightAtTopOfRange,
      repsIncrement: repsIncrement ?? this.repsIncrement,
      repsDeload: repsDeload ?? this.repsDeload,
      repsTarget: repsTarget ?? this.repsTarget,
      sparedRates: sparedRates ?? this.sparedRates,
      cycleBlocks: cycleBlocks ?? this.cycleBlocks,
      cyclePosition: cyclePosition ?? this.cyclePosition,
      cycleNames: cycleNames ?? this.cycleNames,
      targetRpe: targetRpe ?? this.targetRpe,
      gzclTier: gzclTier ?? this.gzclTier,
      gzclStages: gzclStages ?? this.gzclStages,
      gzclStage: gzclStage ?? this.gzclStage,
      gzclAmrapTarget: gzclAmrapTarget ?? this.gzclAmrapTarget,
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
    if (scheme.present) {
      map['scheme'] = Variable<String>(
        $WorkoutItemsTable.$converterscheme.toSql(scheme.value),
      );
    }
    if (schemePercent.present) {
      map['scheme_percent'] = Variable<int>(schemePercent.value);
    }
    if (customSets.present) {
      map['custom_sets'] = Variable<String>(customSets.value);
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
    if (supersetWithPrevious.present) {
      map['superset_with_previous'] = Variable<bool>(
        supersetWithPrevious.value,
      );
    }
    if (addWeightAtTopOfRange.present) {
      map['add_weight_at_top_of_range'] = Variable<bool>(
        addWeightAtTopOfRange.value,
      );
    }
    if (repsIncrement.present) {
      map['reps_increment'] = Variable<double>(repsIncrement.value);
    }
    if (repsDeload.present) {
      map['reps_deload'] = Variable<double>(repsDeload.value);
    }
    if (repsTarget.present) {
      map['reps_target'] = Variable<int>(repsTarget.value);
    }
    if (sparedRates.present) {
      map['spared_rates'] = Variable<String>(sparedRates.value);
    }
    if (cycleBlocks.present) {
      map['cycle_blocks'] = Variable<String>(cycleBlocks.value);
    }
    if (cyclePosition.present) {
      map['cycle_position'] = Variable<int>(cyclePosition.value);
    }
    if (cycleNames.present) {
      map['cycle_names'] = Variable<String>(cycleNames.value);
    }
    if (targetRpe.present) {
      map['target_rpe'] = Variable<int>(targetRpe.value);
    }
    if (gzclTier.present) {
      map['gzcl_tier'] = Variable<String>(
        $WorkoutItemsTable.$convertergzclTiern.toSql(gzclTier.value),
      );
    }
    if (gzclStages.present) {
      map['gzcl_stages'] = Variable<String>(gzclStages.value);
    }
    if (gzclStage.present) {
      map['gzcl_stage'] = Variable<int>(gzclStage.value);
    }
    if (gzclAmrapTarget.present) {
      map['gzcl_amrap_target'] = Variable<int>(gzclAmrapTarget.value);
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
          ..write('scheme: $scheme, ')
          ..write('schemePercent: $schemePercent, ')
          ..write('customSets: $customSets, ')
          ..write('progression: $progression, ')
          ..write('holdSeconds: $holdSeconds, ')
          ..write('increment: $increment, ')
          ..write('successThreshold: $successThreshold, ')
          ..write('deload: $deload, ')
          ..write('failureThreshold: $failureThreshold, ')
          ..write('successStreak: $successStreak, ')
          ..write('failStreak: $failStreak, ')
          ..write('supersetWithPrevious: $supersetWithPrevious, ')
          ..write('addWeightAtTopOfRange: $addWeightAtTopOfRange, ')
          ..write('repsIncrement: $repsIncrement, ')
          ..write('repsDeload: $repsDeload, ')
          ..write('repsTarget: $repsTarget, ')
          ..write('sparedRates: $sparedRates, ')
          ..write('cycleBlocks: $cycleBlocks, ')
          ..write('cyclePosition: $cyclePosition, ')
          ..write('cycleNames: $cycleNames, ')
          ..write('targetRpe: $targetRpe, ')
          ..write('gzclTier: $gzclTier, ')
          ..write('gzclStages: $gzclStages, ')
          ..write('gzclStage: $gzclStage, ')
          ..write('gzclAmrapTarget: $gzclAmrapTarget')
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
  static const VerificationMeta _seedKeyMeta = const VerificationMeta(
    'seedKey',
  );
  @override
  late final GeneratedColumn<String> seedKey = GeneratedColumn<String>(
    'seed_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    seedKey,
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
    if (data.containsKey('seed_key')) {
      context.handle(
        _seedKeyMeta,
        seedKey.isAcceptableOrUnknown(data['seed_key']!, _seedKeyMeta),
      );
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
      seedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seed_key'],
      ),
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

  /// The seed key of the training day this was, or null. Denormalised beside
  /// [name] for the same two reasons the sets denormalise theirs: the template
  /// may be edited or deleted, and the name still has to follow the language.
  final String? seedKey;
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
    this.seedKey,
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
    if (!nullToAbsent || seedKey != null) {
      map['seed_key'] = Variable<String>(seedKey);
    }
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
      seedKey: seedKey == null && nullToAbsent
          ? const Value.absent()
          : Value(seedKey),
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
      seedKey: serializer.fromJson<String?>(json['seedKey']),
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
      'seedKey': serializer.toJson<String?>(seedKey),
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
    Value<String?> seedKey = const Value.absent(),
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
    seedKey: seedKey.present ? seedKey.value : this.seedKey,
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
      seedKey: data.seedKey.present ? data.seedKey.value : this.seedKey,
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
          ..write('seedKey: $seedKey, ')
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
    seedKey,
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
          other.seedKey == this.seedKey &&
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
  final Value<String?> seedKey;
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
    this.seedKey = const Value.absent(),
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
    this.seedKey = const Value.absent(),
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
    Expression<String>? seedKey,
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
      if (seedKey != null) 'seed_key': seedKey,
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
    Value<String?>? seedKey,
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
      seedKey: seedKey ?? this.seedKey,
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
    if (seedKey.present) {
      map['seed_key'] = Variable<String>(seedKey.value);
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
          ..write('seedKey: $seedKey, ')
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
  static const VerificationMeta _exerciseSeedKeyMeta = const VerificationMeta(
    'exerciseSeedKey',
  );
  @override
  late final GeneratedColumn<String> exerciseSeedKey = GeneratedColumn<String>(
    'exercise_seed_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _videoPathMeta = const VerificationMeta(
    'videoPath',
  );
  @override
  late final GeneratedColumn<String> videoPath = GeneratedColumn<String>(
    'video_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedKphMeta = const VerificationMeta(
    'speedKph',
  );
  @override
  late final GeneratedColumn<double> speedKph = GeneratedColumn<double>(
    'speed_kph',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inclinePercentMeta = const VerificationMeta(
    'inclinePercent',
  );
  @override
  late final GeneratedColumn<double> inclinePercent = GeneratedColumn<double>(
    'incline_percent',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resistanceLevelMeta = const VerificationMeta(
    'resistanceLevel',
  );
  @override
  late final GeneratedColumn<int> resistanceLevel = GeneratedColumn<int>(
    'resistance_level',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanceKmMeta = const VerificationMeta(
    'distanceKm',
  );
  @override
  late final GeneratedColumn<double> distanceKm = GeneratedColumn<double>(
    'distance_km',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualRpeMeta = const VerificationMeta(
    'actualRpe',
  );
  @override
  late final GeneratedColumn<int> actualRpe = GeneratedColumn<int>(
    'actual_rpe',
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
    exerciseSeedKey,
    setNumber,
    weight,
    reps,
    done,
    goalReps,
    goalWeight,
    seconds,
    goalSeconds,
    videoPath,
    speedKph,
    inclinePercent,
    resistanceLevel,
    distanceKm,
    actualRpe,
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
    if (data.containsKey('exercise_seed_key')) {
      context.handle(
        _exerciseSeedKeyMeta,
        exerciseSeedKey.isAcceptableOrUnknown(
          data['exercise_seed_key']!,
          _exerciseSeedKeyMeta,
        ),
      );
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
    if (data.containsKey('video_path')) {
      context.handle(
        _videoPathMeta,
        videoPath.isAcceptableOrUnknown(data['video_path']!, _videoPathMeta),
      );
    }
    if (data.containsKey('speed_kph')) {
      context.handle(
        _speedKphMeta,
        speedKph.isAcceptableOrUnknown(data['speed_kph']!, _speedKphMeta),
      );
    }
    if (data.containsKey('incline_percent')) {
      context.handle(
        _inclinePercentMeta,
        inclinePercent.isAcceptableOrUnknown(
          data['incline_percent']!,
          _inclinePercentMeta,
        ),
      );
    }
    if (data.containsKey('resistance_level')) {
      context.handle(
        _resistanceLevelMeta,
        resistanceLevel.isAcceptableOrUnknown(
          data['resistance_level']!,
          _resistanceLevelMeta,
        ),
      );
    }
    if (data.containsKey('distance_km')) {
      context.handle(
        _distanceKmMeta,
        distanceKm.isAcceptableOrUnknown(data['distance_km']!, _distanceKmMeta),
      );
    }
    if (data.containsKey('actual_rpe')) {
      context.handle(
        _actualRpeMeta,
        actualRpe.isAcceptableOrUnknown(data['actual_rpe']!, _actualRpeMeta),
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
      exerciseSeedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_seed_key'],
      ),
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
      videoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_path'],
      ),
      speedKph: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed_kph'],
      ),
      inclinePercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}incline_percent'],
      ),
      resistanceLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resistance_level'],
      ),
      distanceKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_km'],
      ),
      actualRpe: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_rpe'],
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

  /// The seed key of the movement, copied alongside its name and for the same
  /// reason: a logged set has to stay readable after a library edit, *and* has
  /// to follow a language switch. Null for a movement you added yourself, whose
  /// name is the only answer there is.
  final String? exerciseSeedKey;
  final int setNumber;
  final double weight;
  final int reps;
  final bool done;

  /// What the set was aiming for, captured as it was logged.
  ///
  /// Stored rather than looked up from the template later: templates get
  /// edited, and progression has to know what you were actually chasing on the
  /// day. Zero means "no goal recorded", which a set logged outside a template
  /// can legitimately be.
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

  /// The clip filmed of this set, as a path **relative** to the app support
  /// directory (`set_videos/<id>.mp4`). Null on a set nobody filmed, which is
  /// nearly all of them.
  ///
  /// Relative, never absolute: the iOS app-container path carries a UUID that
  /// changes on reinstall and on restore from backup, so an absolute path works
  /// on Android and silently dangles on iOS. See `SetVideoStore`.
  ///
  /// One column rather than a table: one clip per set is the feature, and
  /// several angles of the same set is not.
  final String? videoPath;

  /// Speed, in kilometres per hour. Metric in the column and converted for
  /// display, exactly as [weight] is stored in kilograms — see
  /// `util/cardio_units.dart`.
  final double? speedKph;

  /// The incline, as a percentage. No unit to convert: a 2% treadmill is 2% in
  /// every gym.
  final double? inclinePercent;

  /// The resistance level the machine was set to. A number the machine made up,
  /// so it is stored as it reads and never scaled.
  final int? resistanceLevel;

  /// Distance covered, in kilometres. Metric for the same reason [speedKph] is.
  final double? distanceKm;

  /// The lifter's optional set RPE in tenths (85 is RPE 8.5).
  final int? actualRpe;
  const SessionSet({
    required this.id,
    required this.sessionId,
    this.exerciseId,
    required this.exerciseName,
    this.exerciseSeedKey,
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.done,
    required this.goalReps,
    this.goalWeight,
    this.seconds,
    this.goalSeconds,
    this.videoPath,
    this.speedKph,
    this.inclinePercent,
    this.resistanceLevel,
    this.distanceKm,
    this.actualRpe,
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
    if (!nullToAbsent || exerciseSeedKey != null) {
      map['exercise_seed_key'] = Variable<String>(exerciseSeedKey);
    }
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
    if (!nullToAbsent || videoPath != null) {
      map['video_path'] = Variable<String>(videoPath);
    }
    if (!nullToAbsent || speedKph != null) {
      map['speed_kph'] = Variable<double>(speedKph);
    }
    if (!nullToAbsent || inclinePercent != null) {
      map['incline_percent'] = Variable<double>(inclinePercent);
    }
    if (!nullToAbsent || resistanceLevel != null) {
      map['resistance_level'] = Variable<int>(resistanceLevel);
    }
    if (!nullToAbsent || distanceKm != null) {
      map['distance_km'] = Variable<double>(distanceKm);
    }
    if (!nullToAbsent || actualRpe != null) {
      map['actual_rpe'] = Variable<int>(actualRpe);
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
      exerciseSeedKey: exerciseSeedKey == null && nullToAbsent
          ? const Value.absent()
          : Value(exerciseSeedKey),
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
      videoPath: videoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(videoPath),
      speedKph: speedKph == null && nullToAbsent
          ? const Value.absent()
          : Value(speedKph),
      inclinePercent: inclinePercent == null && nullToAbsent
          ? const Value.absent()
          : Value(inclinePercent),
      resistanceLevel: resistanceLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(resistanceLevel),
      distanceKm: distanceKm == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceKm),
      actualRpe: actualRpe == null && nullToAbsent
          ? const Value.absent()
          : Value(actualRpe),
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
      exerciseSeedKey: serializer.fromJson<String?>(json['exerciseSeedKey']),
      setNumber: serializer.fromJson<int>(json['setNumber']),
      weight: serializer.fromJson<double>(json['weight']),
      reps: serializer.fromJson<int>(json['reps']),
      done: serializer.fromJson<bool>(json['done']),
      goalReps: serializer.fromJson<int>(json['goalReps']),
      goalWeight: serializer.fromJson<double?>(json['goalWeight']),
      seconds: serializer.fromJson<int?>(json['seconds']),
      goalSeconds: serializer.fromJson<int?>(json['goalSeconds']),
      videoPath: serializer.fromJson<String?>(json['videoPath']),
      speedKph: serializer.fromJson<double?>(json['speedKph']),
      inclinePercent: serializer.fromJson<double?>(json['inclinePercent']),
      resistanceLevel: serializer.fromJson<int?>(json['resistanceLevel']),
      distanceKm: serializer.fromJson<double?>(json['distanceKm']),
      actualRpe: serializer.fromJson<int?>(json['actualRpe']),
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
      'exerciseSeedKey': serializer.toJson<String?>(exerciseSeedKey),
      'setNumber': serializer.toJson<int>(setNumber),
      'weight': serializer.toJson<double>(weight),
      'reps': serializer.toJson<int>(reps),
      'done': serializer.toJson<bool>(done),
      'goalReps': serializer.toJson<int>(goalReps),
      'goalWeight': serializer.toJson<double?>(goalWeight),
      'seconds': serializer.toJson<int?>(seconds),
      'goalSeconds': serializer.toJson<int?>(goalSeconds),
      'videoPath': serializer.toJson<String?>(videoPath),
      'speedKph': serializer.toJson<double?>(speedKph),
      'inclinePercent': serializer.toJson<double?>(inclinePercent),
      'resistanceLevel': serializer.toJson<int?>(resistanceLevel),
      'distanceKm': serializer.toJson<double?>(distanceKm),
      'actualRpe': serializer.toJson<int?>(actualRpe),
    };
  }

  SessionSet copyWith({
    int? id,
    int? sessionId,
    Value<int?> exerciseId = const Value.absent(),
    String? exerciseName,
    Value<String?> exerciseSeedKey = const Value.absent(),
    int? setNumber,
    double? weight,
    int? reps,
    bool? done,
    int? goalReps,
    Value<double?> goalWeight = const Value.absent(),
    Value<int?> seconds = const Value.absent(),
    Value<int?> goalSeconds = const Value.absent(),
    Value<String?> videoPath = const Value.absent(),
    Value<double?> speedKph = const Value.absent(),
    Value<double?> inclinePercent = const Value.absent(),
    Value<int?> resistanceLevel = const Value.absent(),
    Value<double?> distanceKm = const Value.absent(),
    Value<int?> actualRpe = const Value.absent(),
  }) => SessionSet(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    exerciseId: exerciseId.present ? exerciseId.value : this.exerciseId,
    exerciseName: exerciseName ?? this.exerciseName,
    exerciseSeedKey: exerciseSeedKey.present
        ? exerciseSeedKey.value
        : this.exerciseSeedKey,
    setNumber: setNumber ?? this.setNumber,
    weight: weight ?? this.weight,
    reps: reps ?? this.reps,
    done: done ?? this.done,
    goalReps: goalReps ?? this.goalReps,
    goalWeight: goalWeight.present ? goalWeight.value : this.goalWeight,
    seconds: seconds.present ? seconds.value : this.seconds,
    goalSeconds: goalSeconds.present ? goalSeconds.value : this.goalSeconds,
    videoPath: videoPath.present ? videoPath.value : this.videoPath,
    speedKph: speedKph.present ? speedKph.value : this.speedKph,
    inclinePercent: inclinePercent.present
        ? inclinePercent.value
        : this.inclinePercent,
    resistanceLevel: resistanceLevel.present
        ? resistanceLevel.value
        : this.resistanceLevel,
    distanceKm: distanceKm.present ? distanceKm.value : this.distanceKm,
    actualRpe: actualRpe.present ? actualRpe.value : this.actualRpe,
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
      exerciseSeedKey: data.exerciseSeedKey.present
          ? data.exerciseSeedKey.value
          : this.exerciseSeedKey,
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
      videoPath: data.videoPath.present ? data.videoPath.value : this.videoPath,
      speedKph: data.speedKph.present ? data.speedKph.value : this.speedKph,
      inclinePercent: data.inclinePercent.present
          ? data.inclinePercent.value
          : this.inclinePercent,
      resistanceLevel: data.resistanceLevel.present
          ? data.resistanceLevel.value
          : this.resistanceLevel,
      distanceKm: data.distanceKm.present
          ? data.distanceKm.value
          : this.distanceKm,
      actualRpe: data.actualRpe.present ? data.actualRpe.value : this.actualRpe,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionSet(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('exerciseSeedKey: $exerciseSeedKey, ')
          ..write('setNumber: $setNumber, ')
          ..write('weight: $weight, ')
          ..write('reps: $reps, ')
          ..write('done: $done, ')
          ..write('goalReps: $goalReps, ')
          ..write('goalWeight: $goalWeight, ')
          ..write('seconds: $seconds, ')
          ..write('goalSeconds: $goalSeconds, ')
          ..write('videoPath: $videoPath, ')
          ..write('speedKph: $speedKph, ')
          ..write('inclinePercent: $inclinePercent, ')
          ..write('resistanceLevel: $resistanceLevel, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('actualRpe: $actualRpe')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    exerciseId,
    exerciseName,
    exerciseSeedKey,
    setNumber,
    weight,
    reps,
    done,
    goalReps,
    goalWeight,
    seconds,
    goalSeconds,
    videoPath,
    speedKph,
    inclinePercent,
    resistanceLevel,
    distanceKm,
    actualRpe,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionSet &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.exerciseId == this.exerciseId &&
          other.exerciseName == this.exerciseName &&
          other.exerciseSeedKey == this.exerciseSeedKey &&
          other.setNumber == this.setNumber &&
          other.weight == this.weight &&
          other.reps == this.reps &&
          other.done == this.done &&
          other.goalReps == this.goalReps &&
          other.goalWeight == this.goalWeight &&
          other.seconds == this.seconds &&
          other.goalSeconds == this.goalSeconds &&
          other.videoPath == this.videoPath &&
          other.speedKph == this.speedKph &&
          other.inclinePercent == this.inclinePercent &&
          other.resistanceLevel == this.resistanceLevel &&
          other.distanceKm == this.distanceKm &&
          other.actualRpe == this.actualRpe);
}

class SessionSetsCompanion extends UpdateCompanion<SessionSet> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int?> exerciseId;
  final Value<String> exerciseName;
  final Value<String?> exerciseSeedKey;
  final Value<int> setNumber;
  final Value<double> weight;
  final Value<int> reps;
  final Value<bool> done;
  final Value<int> goalReps;
  final Value<double?> goalWeight;
  final Value<int?> seconds;
  final Value<int?> goalSeconds;
  final Value<String?> videoPath;
  final Value<double?> speedKph;
  final Value<double?> inclinePercent;
  final Value<int?> resistanceLevel;
  final Value<double?> distanceKm;
  final Value<int?> actualRpe;
  const SessionSetsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.exerciseName = const Value.absent(),
    this.exerciseSeedKey = const Value.absent(),
    this.setNumber = const Value.absent(),
    this.weight = const Value.absent(),
    this.reps = const Value.absent(),
    this.done = const Value.absent(),
    this.goalReps = const Value.absent(),
    this.goalWeight = const Value.absent(),
    this.seconds = const Value.absent(),
    this.goalSeconds = const Value.absent(),
    this.videoPath = const Value.absent(),
    this.speedKph = const Value.absent(),
    this.inclinePercent = const Value.absent(),
    this.resistanceLevel = const Value.absent(),
    this.distanceKm = const Value.absent(),
    this.actualRpe = const Value.absent(),
  });
  SessionSetsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    this.exerciseId = const Value.absent(),
    required String exerciseName,
    this.exerciseSeedKey = const Value.absent(),
    required int setNumber,
    this.weight = const Value.absent(),
    this.reps = const Value.absent(),
    this.done = const Value.absent(),
    this.goalReps = const Value.absent(),
    this.goalWeight = const Value.absent(),
    this.seconds = const Value.absent(),
    this.goalSeconds = const Value.absent(),
    this.videoPath = const Value.absent(),
    this.speedKph = const Value.absent(),
    this.inclinePercent = const Value.absent(),
    this.resistanceLevel = const Value.absent(),
    this.distanceKm = const Value.absent(),
    this.actualRpe = const Value.absent(),
  }) : sessionId = Value(sessionId),
       exerciseName = Value(exerciseName),
       setNumber = Value(setNumber);
  static Insertable<SessionSet> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? exerciseId,
    Expression<String>? exerciseName,
    Expression<String>? exerciseSeedKey,
    Expression<int>? setNumber,
    Expression<double>? weight,
    Expression<int>? reps,
    Expression<bool>? done,
    Expression<int>? goalReps,
    Expression<double>? goalWeight,
    Expression<int>? seconds,
    Expression<int>? goalSeconds,
    Expression<String>? videoPath,
    Expression<double>? speedKph,
    Expression<double>? inclinePercent,
    Expression<int>? resistanceLevel,
    Expression<double>? distanceKm,
    Expression<int>? actualRpe,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (exerciseName != null) 'exercise_name': exerciseName,
      if (exerciseSeedKey != null) 'exercise_seed_key': exerciseSeedKey,
      if (setNumber != null) 'set_number': setNumber,
      if (weight != null) 'weight': weight,
      if (reps != null) 'reps': reps,
      if (done != null) 'done': done,
      if (goalReps != null) 'goal_reps': goalReps,
      if (goalWeight != null) 'goal_weight': goalWeight,
      if (seconds != null) 'seconds': seconds,
      if (goalSeconds != null) 'goal_seconds': goalSeconds,
      if (videoPath != null) 'video_path': videoPath,
      if (speedKph != null) 'speed_kph': speedKph,
      if (inclinePercent != null) 'incline_percent': inclinePercent,
      if (resistanceLevel != null) 'resistance_level': resistanceLevel,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (actualRpe != null) 'actual_rpe': actualRpe,
    });
  }

  SessionSetsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<int?>? exerciseId,
    Value<String>? exerciseName,
    Value<String?>? exerciseSeedKey,
    Value<int>? setNumber,
    Value<double>? weight,
    Value<int>? reps,
    Value<bool>? done,
    Value<int>? goalReps,
    Value<double?>? goalWeight,
    Value<int?>? seconds,
    Value<int?>? goalSeconds,
    Value<String?>? videoPath,
    Value<double?>? speedKph,
    Value<double?>? inclinePercent,
    Value<int?>? resistanceLevel,
    Value<double?>? distanceKm,
    Value<int?>? actualRpe,
  }) {
    return SessionSetsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      exerciseSeedKey: exerciseSeedKey ?? this.exerciseSeedKey,
      setNumber: setNumber ?? this.setNumber,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      done: done ?? this.done,
      goalReps: goalReps ?? this.goalReps,
      goalWeight: goalWeight ?? this.goalWeight,
      seconds: seconds ?? this.seconds,
      goalSeconds: goalSeconds ?? this.goalSeconds,
      videoPath: videoPath ?? this.videoPath,
      speedKph: speedKph ?? this.speedKph,
      inclinePercent: inclinePercent ?? this.inclinePercent,
      resistanceLevel: resistanceLevel ?? this.resistanceLevel,
      distanceKm: distanceKm ?? this.distanceKm,
      actualRpe: actualRpe ?? this.actualRpe,
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
    if (exerciseSeedKey.present) {
      map['exercise_seed_key'] = Variable<String>(exerciseSeedKey.value);
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
    if (videoPath.present) {
      map['video_path'] = Variable<String>(videoPath.value);
    }
    if (speedKph.present) {
      map['speed_kph'] = Variable<double>(speedKph.value);
    }
    if (inclinePercent.present) {
      map['incline_percent'] = Variable<double>(inclinePercent.value);
    }
    if (resistanceLevel.present) {
      map['resistance_level'] = Variable<int>(resistanceLevel.value);
    }
    if (distanceKm.present) {
      map['distance_km'] = Variable<double>(distanceKm.value);
    }
    if (actualRpe.present) {
      map['actual_rpe'] = Variable<int>(actualRpe.value);
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
          ..write('exerciseSeedKey: $exerciseSeedKey, ')
          ..write('setNumber: $setNumber, ')
          ..write('weight: $weight, ')
          ..write('reps: $reps, ')
          ..write('done: $done, ')
          ..write('goalReps: $goalReps, ')
          ..write('goalWeight: $goalWeight, ')
          ..write('seconds: $seconds, ')
          ..write('goalSeconds: $goalSeconds, ')
          ..write('videoPath: $videoPath, ')
          ..write('speedKph: $speedKph, ')
          ..write('inclinePercent: $inclinePercent, ')
          ..write('resistanceLevel: $resistanceLevel, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('actualRpe: $actualRpe')
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _layoffDaysMeta = const VerificationMeta(
    'layoffDays',
  );
  @override
  late final GeneratedColumn<int> layoffDays = GeneratedColumn<int>(
    'layoff_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultLayoffDays),
  );
  static const VerificationMeta _layoffPercentMeta = const VerificationMeta(
    'layoffPercent',
  );
  @override
  late final GeneratedColumn<int> layoffPercent = GeneratedColumn<int>(
    'layoff_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultLayoffPercent),
  );
  static const VerificationMeta _plateInventoryMeta = const VerificationMeta(
    'plateInventory',
  );
  @override
  late final GeneratedColumn<String> plateInventory = GeneratedColumn<String>(
    'plate_inventory',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plateInventoryLbMeta = const VerificationMeta(
    'plateInventoryLb',
  );
  @override
  late final GeneratedColumn<String> plateInventoryLb = GeneratedColumn<String>(
    'plate_inventory_lb',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barWeightMeta = const VerificationMeta(
    'barWeight',
  );
  @override
  late final GeneratedColumn<double> barWeight = GeneratedColumn<double>(
    'bar_weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tutorialSeenMeta = const VerificationMeta(
    'tutorialSeen',
  );
  @override
  late final GeneratedColumn<bool> tutorialSeen = GeneratedColumn<bool>(
    'tutorial_seen',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tutorial_seen" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _textScaleMeta = const VerificationMeta(
    'textScale',
  );
  @override
  late final GeneratedColumn<double> textScale = GeneratedColumn<double>(
    'text_scale',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _themePresetIdMeta = const VerificationMeta(
    'themePresetId',
  );
  @override
  late final GeneratedColumn<String> themePresetId = GeneratedColumn<String>(
    'theme_preset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoHeightMeta = const VerificationMeta(
    'videoHeight',
  );
  @override
  late final GeneratedColumn<int> videoHeight = GeneratedColumn<int>(
    'video_height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultVideoHeight),
  );
  static const VerificationMeta _videoMaxSecondsMeta = const VerificationMeta(
    'videoMaxSeconds',
  );
  @override
  late final GeneratedColumn<int> videoMaxSeconds = GeneratedColumn<int>(
    'video_max_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultVideoSeconds),
  );
  static const VerificationMeta _localeTagMeta = const VerificationMeta(
    'localeTag',
  );
  @override
  late final GeneratedColumn<String> localeTag = GeneratedColumn<String>(
    'locale_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _warmupSetsMeta = const VerificationMeta(
    'warmupSets',
  );
  @override
  late final GeneratedColumn<int> warmupSets = GeneratedColumn<int>(
    'warmup_sets',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultWarmupSets),
  );
  static const VerificationMeta _advancedProgrammingMeta =
      const VerificationMeta('advancedProgramming');
  @override
  late final GeneratedColumn<bool> advancedProgramming = GeneratedColumn<bool>(
    'advanced_programming',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("advanced_programming" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    weightUnit,
    activeRoutineId,
    layoffDays,
    layoffPercent,
    plateInventory,
    plateInventoryLb,
    barWeight,
    tutorialSeen,
    textScale,
    themePresetId,
    videoHeight,
    videoMaxSeconds,
    localeTag,
    warmupSets,
    advancedProgramming,
  ];
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
    if (data.containsKey('layoff_days')) {
      context.handle(
        _layoffDaysMeta,
        layoffDays.isAcceptableOrUnknown(data['layoff_days']!, _layoffDaysMeta),
      );
    }
    if (data.containsKey('layoff_percent')) {
      context.handle(
        _layoffPercentMeta,
        layoffPercent.isAcceptableOrUnknown(
          data['layoff_percent']!,
          _layoffPercentMeta,
        ),
      );
    }
    if (data.containsKey('plate_inventory')) {
      context.handle(
        _plateInventoryMeta,
        plateInventory.isAcceptableOrUnknown(
          data['plate_inventory']!,
          _plateInventoryMeta,
        ),
      );
    }
    if (data.containsKey('plate_inventory_lb')) {
      context.handle(
        _plateInventoryLbMeta,
        plateInventoryLb.isAcceptableOrUnknown(
          data['plate_inventory_lb']!,
          _plateInventoryLbMeta,
        ),
      );
    }
    if (data.containsKey('bar_weight')) {
      context.handle(
        _barWeightMeta,
        barWeight.isAcceptableOrUnknown(data['bar_weight']!, _barWeightMeta),
      );
    }
    if (data.containsKey('tutorial_seen')) {
      context.handle(
        _tutorialSeenMeta,
        tutorialSeen.isAcceptableOrUnknown(
          data['tutorial_seen']!,
          _tutorialSeenMeta,
        ),
      );
    }
    if (data.containsKey('text_scale')) {
      context.handle(
        _textScaleMeta,
        textScale.isAcceptableOrUnknown(data['text_scale']!, _textScaleMeta),
      );
    }
    if (data.containsKey('theme_preset_id')) {
      context.handle(
        _themePresetIdMeta,
        themePresetId.isAcceptableOrUnknown(
          data['theme_preset_id']!,
          _themePresetIdMeta,
        ),
      );
    }
    if (data.containsKey('video_height')) {
      context.handle(
        _videoHeightMeta,
        videoHeight.isAcceptableOrUnknown(
          data['video_height']!,
          _videoHeightMeta,
        ),
      );
    }
    if (data.containsKey('video_max_seconds')) {
      context.handle(
        _videoMaxSecondsMeta,
        videoMaxSeconds.isAcceptableOrUnknown(
          data['video_max_seconds']!,
          _videoMaxSecondsMeta,
        ),
      );
    }
    if (data.containsKey('locale_tag')) {
      context.handle(
        _localeTagMeta,
        localeTag.isAcceptableOrUnknown(data['locale_tag']!, _localeTagMeta),
      );
    }
    if (data.containsKey('warmup_sets')) {
      context.handle(
        _warmupSetsMeta,
        warmupSets.isAcceptableOrUnknown(data['warmup_sets']!, _warmupSetsMeta),
      );
    }
    if (data.containsKey('advanced_programming')) {
      context.handle(
        _advancedProgrammingMeta,
        advancedProgramming.isAcceptableOrUnknown(
          data['advanced_programming']!,
          _advancedProgrammingMeta,
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
      ),
      activeRoutineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_routine_id'],
      ),
      layoffDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}layoff_days'],
      )!,
      layoffPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}layoff_percent'],
      )!,
      plateInventory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plate_inventory'],
      ),
      plateInventoryLb: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plate_inventory_lb'],
      ),
      barWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bar_weight'],
      ),
      tutorialSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tutorial_seen'],
      )!,
      textScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}text_scale'],
      )!,
      themePresetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_preset_id'],
      ),
      videoHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}video_height'],
      )!,
      videoMaxSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}video_max_seconds'],
      )!,
      localeTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locale_tag'],
      ),
      warmupSets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}warmup_sets'],
      )!,
      advancedProgramming: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}advanced_programming'],
      )!,
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
  ///
  /// **Null means the question has not been asked yet**, which is not the same
  /// as kilograms: a fresh install opens on the first-run unit choice, and this
  /// column is what says whether it still has to. Everything that only wants to
  /// *display* a weight reads null as kilograms, so nothing downstream has to
  /// cope with a missing unit.
  final String? weightUnit;

  /// The routine the Today tab is currently about. Null means "not chosen yet",
  /// which makes Today fall back to a routine chooser. Not a foreign key: a
  /// dangling id after a delete resolves to null rather than failing.
  final int? activeRoutineId;

  /// Days away from a workout before returning to it offers a back-off. Zero
  /// switches layoff deloads off entirely.
  final int layoffDays;

  /// How much a layoff cuts the target for each whole period away, as a
  /// percentage — see `layoff.dart`.
  final int layoffPercent;

  /// The plates a metric gym owns, encoded — see `plates.dart`.
  ///
  /// Null means the user has never edited it, which is not the same as owning
  /// no plates: it lets the standard rack stand in.
  final String? plateInventory;

  /// The same for a gym stocking pounds. A separate rack rather than a
  /// conversion of [plateInventory]: see [resolvePlateSettings] for why.
  final String? plateInventoryLb;

  /// What the bar weighs by default, in kg — an exercise may override it with
  /// `Exercises.barWeight`. Null falls back to the standard bar for the chosen
  /// unit, for the same reason as [plateInventory].
  final double? barWeight;

  /// Whether the first-run tutorial has already been shown. False on a fresh
  /// install, so the coach marks run exactly once; set true when the tour is
  /// completed or skipped. An upgrade marks it true — an existing user is not a
  /// first run and should never be ambushed by it mid-program. Re-running the
  /// tour from the help menu does not clear it.
  final bool tutorialSeen;

  /// The user's own text-size nudge, *on top of* the phone's setting.
  ///
  /// 1.0 means "whatever the system says", which is the default and the right
  /// answer for most people — Android's own text size is system-wide and
  /// already discoverable. This exists for the gap it leaves: wanting this app
  /// larger without enlarging everything else, or wanting it smaller to fit
  /// more of a workout on screen.
  ///
  /// It multiplies the system scale rather than replacing it, and the product
  /// is clamped — see `kTextScaleChoices` and `resolveTextScale`. A control
  /// that can produce a layout nobody has checked is not an accessibility
  /// feature.
  final double textScale;

  /// Which colour theme is active: a preset slug (`ignition`, `graphite`, …),
  /// `custom:<n>` naming a row of [CustomThemes], or null. Null means the
  /// default preset, so an install that never touched the setting looks exactly
  /// as it always did.
  ///
  /// Nothing keeps this in step with [CustomThemes] except [deleteCustomTheme],
  /// which clears it when it removes the row it names. A slug left dangling by
  /// any other route resolves to the default rather than to nothing — see
  /// `resolvePalette`.
  final String? themePresetId;

  /// The height a set clip is filmed at, in pixels: 480 or 720.
  ///
  /// 720 by default. 1080 is deliberately not on offer — it is roughly two and
  /// a half times the bytes of 720 for a judgement (depth, bar path) that 720
  /// already answers, and video is the only thing this app stores that can fill
  /// a phone. See `kVideoHeights`.
  final int videoHeight;

  /// The hard stop on one clip, in seconds: 60 or 180.
  ///
  /// Recording ends itself here rather than warning. The failure mode that
  /// fills a phone is a recording nobody stopped — you rack the bar, walk off,
  /// and the app films the ceiling. 60 covers any straight set; the longer step
  /// exists for a 20-rep squat set or a held exercise.
  final int videoMaxSeconds;

  /// The language the user picked, as `uk` or `pt_BR` — see `util/locales.dart`.
  ///
  /// Null means "follow the phone", which is the default and the right answer
  /// for almost everybody: the phone has already been asked this question. It
  /// exists for the gap that leaves — a phone kept in one language by an
  /// employer or a habit, and an app you would rather read in another.
  final String? localeTag;

  /// How many warm-up rungs every exercise in a session opens with, before the
  /// live stepper touches it — see `warmup.dart`.
  ///
  /// The settings stepper holds it between 1 and [kMaxWarmupSets]. Zero is not
  /// on offer there: skipping the ramp is a decision about the movement you are
  /// on, which the session's own stepper already makes.
  ///
  /// **Declared last on purpose.** `ALTER TABLE … ADD COLUMN` appends, so a
  /// database that climbed the v2 rung carries this column at the end. Adding it
  /// here rather than beside the other counts keeps a fresh install and an
  /// upgraded one on exactly the same table, right down to the column order.
  final int warmupSets;

  /// Dormant. It once gated whether the builder offered cycles, per-set rep
  /// ranges and training maxes; it gates nothing now — those are ordinary
  /// options, on every install. The column stays because a shipped rung wrote
  /// it and a rung is never rewritten; nothing reads it.
  ///
  /// **Declared last**, for the reason [warmupSets] gives above; the note moves
  /// to whatever column comes next.
  final bool advancedProgramming;
  const Setting({
    required this.id,
    this.weightUnit,
    this.activeRoutineId,
    required this.layoffDays,
    required this.layoffPercent,
    this.plateInventory,
    this.plateInventoryLb,
    this.barWeight,
    required this.tutorialSeen,
    required this.textScale,
    this.themePresetId,
    required this.videoHeight,
    required this.videoMaxSeconds,
    this.localeTag,
    required this.warmupSets,
    required this.advancedProgramming,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || weightUnit != null) {
      map['weight_unit'] = Variable<String>(weightUnit);
    }
    if (!nullToAbsent || activeRoutineId != null) {
      map['active_routine_id'] = Variable<int>(activeRoutineId);
    }
    map['layoff_days'] = Variable<int>(layoffDays);
    map['layoff_percent'] = Variable<int>(layoffPercent);
    if (!nullToAbsent || plateInventory != null) {
      map['plate_inventory'] = Variable<String>(plateInventory);
    }
    if (!nullToAbsent || plateInventoryLb != null) {
      map['plate_inventory_lb'] = Variable<String>(plateInventoryLb);
    }
    if (!nullToAbsent || barWeight != null) {
      map['bar_weight'] = Variable<double>(barWeight);
    }
    map['tutorial_seen'] = Variable<bool>(tutorialSeen);
    map['text_scale'] = Variable<double>(textScale);
    if (!nullToAbsent || themePresetId != null) {
      map['theme_preset_id'] = Variable<String>(themePresetId);
    }
    map['video_height'] = Variable<int>(videoHeight);
    map['video_max_seconds'] = Variable<int>(videoMaxSeconds);
    if (!nullToAbsent || localeTag != null) {
      map['locale_tag'] = Variable<String>(localeTag);
    }
    map['warmup_sets'] = Variable<int>(warmupSets);
    map['advanced_programming'] = Variable<bool>(advancedProgramming);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      weightUnit: weightUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(weightUnit),
      activeRoutineId: activeRoutineId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeRoutineId),
      layoffDays: Value(layoffDays),
      layoffPercent: Value(layoffPercent),
      plateInventory: plateInventory == null && nullToAbsent
          ? const Value.absent()
          : Value(plateInventory),
      plateInventoryLb: plateInventoryLb == null && nullToAbsent
          ? const Value.absent()
          : Value(plateInventoryLb),
      barWeight: barWeight == null && nullToAbsent
          ? const Value.absent()
          : Value(barWeight),
      tutorialSeen: Value(tutorialSeen),
      textScale: Value(textScale),
      themePresetId: themePresetId == null && nullToAbsent
          ? const Value.absent()
          : Value(themePresetId),
      videoHeight: Value(videoHeight),
      videoMaxSeconds: Value(videoMaxSeconds),
      localeTag: localeTag == null && nullToAbsent
          ? const Value.absent()
          : Value(localeTag),
      warmupSets: Value(warmupSets),
      advancedProgramming: Value(advancedProgramming),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      id: serializer.fromJson<int>(json['id']),
      weightUnit: serializer.fromJson<String?>(json['weightUnit']),
      activeRoutineId: serializer.fromJson<int?>(json['activeRoutineId']),
      layoffDays: serializer.fromJson<int>(json['layoffDays']),
      layoffPercent: serializer.fromJson<int>(json['layoffPercent']),
      plateInventory: serializer.fromJson<String?>(json['plateInventory']),
      plateInventoryLb: serializer.fromJson<String?>(json['plateInventoryLb']),
      barWeight: serializer.fromJson<double?>(json['barWeight']),
      tutorialSeen: serializer.fromJson<bool>(json['tutorialSeen']),
      textScale: serializer.fromJson<double>(json['textScale']),
      themePresetId: serializer.fromJson<String?>(json['themePresetId']),
      videoHeight: serializer.fromJson<int>(json['videoHeight']),
      videoMaxSeconds: serializer.fromJson<int>(json['videoMaxSeconds']),
      localeTag: serializer.fromJson<String?>(json['localeTag']),
      warmupSets: serializer.fromJson<int>(json['warmupSets']),
      advancedProgramming: serializer.fromJson<bool>(
        json['advancedProgramming'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'weightUnit': serializer.toJson<String?>(weightUnit),
      'activeRoutineId': serializer.toJson<int?>(activeRoutineId),
      'layoffDays': serializer.toJson<int>(layoffDays),
      'layoffPercent': serializer.toJson<int>(layoffPercent),
      'plateInventory': serializer.toJson<String?>(plateInventory),
      'plateInventoryLb': serializer.toJson<String?>(plateInventoryLb),
      'barWeight': serializer.toJson<double?>(barWeight),
      'tutorialSeen': serializer.toJson<bool>(tutorialSeen),
      'textScale': serializer.toJson<double>(textScale),
      'themePresetId': serializer.toJson<String?>(themePresetId),
      'videoHeight': serializer.toJson<int>(videoHeight),
      'videoMaxSeconds': serializer.toJson<int>(videoMaxSeconds),
      'localeTag': serializer.toJson<String?>(localeTag),
      'warmupSets': serializer.toJson<int>(warmupSets),
      'advancedProgramming': serializer.toJson<bool>(advancedProgramming),
    };
  }

  Setting copyWith({
    int? id,
    Value<String?> weightUnit = const Value.absent(),
    Value<int?> activeRoutineId = const Value.absent(),
    int? layoffDays,
    int? layoffPercent,
    Value<String?> plateInventory = const Value.absent(),
    Value<String?> plateInventoryLb = const Value.absent(),
    Value<double?> barWeight = const Value.absent(),
    bool? tutorialSeen,
    double? textScale,
    Value<String?> themePresetId = const Value.absent(),
    int? videoHeight,
    int? videoMaxSeconds,
    Value<String?> localeTag = const Value.absent(),
    int? warmupSets,
    bool? advancedProgramming,
  }) => Setting(
    id: id ?? this.id,
    weightUnit: weightUnit.present ? weightUnit.value : this.weightUnit,
    activeRoutineId: activeRoutineId.present
        ? activeRoutineId.value
        : this.activeRoutineId,
    layoffDays: layoffDays ?? this.layoffDays,
    layoffPercent: layoffPercent ?? this.layoffPercent,
    plateInventory: plateInventory.present
        ? plateInventory.value
        : this.plateInventory,
    plateInventoryLb: plateInventoryLb.present
        ? plateInventoryLb.value
        : this.plateInventoryLb,
    barWeight: barWeight.present ? barWeight.value : this.barWeight,
    tutorialSeen: tutorialSeen ?? this.tutorialSeen,
    textScale: textScale ?? this.textScale,
    themePresetId: themePresetId.present
        ? themePresetId.value
        : this.themePresetId,
    videoHeight: videoHeight ?? this.videoHeight,
    videoMaxSeconds: videoMaxSeconds ?? this.videoMaxSeconds,
    localeTag: localeTag.present ? localeTag.value : this.localeTag,
    warmupSets: warmupSets ?? this.warmupSets,
    advancedProgramming: advancedProgramming ?? this.advancedProgramming,
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
      layoffDays: data.layoffDays.present
          ? data.layoffDays.value
          : this.layoffDays,
      layoffPercent: data.layoffPercent.present
          ? data.layoffPercent.value
          : this.layoffPercent,
      plateInventory: data.plateInventory.present
          ? data.plateInventory.value
          : this.plateInventory,
      plateInventoryLb: data.plateInventoryLb.present
          ? data.plateInventoryLb.value
          : this.plateInventoryLb,
      barWeight: data.barWeight.present ? data.barWeight.value : this.barWeight,
      tutorialSeen: data.tutorialSeen.present
          ? data.tutorialSeen.value
          : this.tutorialSeen,
      textScale: data.textScale.present ? data.textScale.value : this.textScale,
      themePresetId: data.themePresetId.present
          ? data.themePresetId.value
          : this.themePresetId,
      videoHeight: data.videoHeight.present
          ? data.videoHeight.value
          : this.videoHeight,
      videoMaxSeconds: data.videoMaxSeconds.present
          ? data.videoMaxSeconds.value
          : this.videoMaxSeconds,
      localeTag: data.localeTag.present ? data.localeTag.value : this.localeTag,
      warmupSets: data.warmupSets.present
          ? data.warmupSets.value
          : this.warmupSets,
      advancedProgramming: data.advancedProgramming.present
          ? data.advancedProgramming.value
          : this.advancedProgramming,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('id: $id, ')
          ..write('weightUnit: $weightUnit, ')
          ..write('activeRoutineId: $activeRoutineId, ')
          ..write('layoffDays: $layoffDays, ')
          ..write('layoffPercent: $layoffPercent, ')
          ..write('plateInventory: $plateInventory, ')
          ..write('plateInventoryLb: $plateInventoryLb, ')
          ..write('barWeight: $barWeight, ')
          ..write('tutorialSeen: $tutorialSeen, ')
          ..write('textScale: $textScale, ')
          ..write('themePresetId: $themePresetId, ')
          ..write('videoHeight: $videoHeight, ')
          ..write('videoMaxSeconds: $videoMaxSeconds, ')
          ..write('localeTag: $localeTag, ')
          ..write('warmupSets: $warmupSets, ')
          ..write('advancedProgramming: $advancedProgramming')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    weightUnit,
    activeRoutineId,
    layoffDays,
    layoffPercent,
    plateInventory,
    plateInventoryLb,
    barWeight,
    tutorialSeen,
    textScale,
    themePresetId,
    videoHeight,
    videoMaxSeconds,
    localeTag,
    warmupSets,
    advancedProgramming,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.id == this.id &&
          other.weightUnit == this.weightUnit &&
          other.activeRoutineId == this.activeRoutineId &&
          other.layoffDays == this.layoffDays &&
          other.layoffPercent == this.layoffPercent &&
          other.plateInventory == this.plateInventory &&
          other.plateInventoryLb == this.plateInventoryLb &&
          other.barWeight == this.barWeight &&
          other.tutorialSeen == this.tutorialSeen &&
          other.textScale == this.textScale &&
          other.themePresetId == this.themePresetId &&
          other.videoHeight == this.videoHeight &&
          other.videoMaxSeconds == this.videoMaxSeconds &&
          other.localeTag == this.localeTag &&
          other.warmupSets == this.warmupSets &&
          other.advancedProgramming == this.advancedProgramming);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<int> id;
  final Value<String?> weightUnit;
  final Value<int?> activeRoutineId;
  final Value<int> layoffDays;
  final Value<int> layoffPercent;
  final Value<String?> plateInventory;
  final Value<String?> plateInventoryLb;
  final Value<double?> barWeight;
  final Value<bool> tutorialSeen;
  final Value<double> textScale;
  final Value<String?> themePresetId;
  final Value<int> videoHeight;
  final Value<int> videoMaxSeconds;
  final Value<String?> localeTag;
  final Value<int> warmupSets;
  final Value<bool> advancedProgramming;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.weightUnit = const Value.absent(),
    this.activeRoutineId = const Value.absent(),
    this.layoffDays = const Value.absent(),
    this.layoffPercent = const Value.absent(),
    this.plateInventory = const Value.absent(),
    this.plateInventoryLb = const Value.absent(),
    this.barWeight = const Value.absent(),
    this.tutorialSeen = const Value.absent(),
    this.textScale = const Value.absent(),
    this.themePresetId = const Value.absent(),
    this.videoHeight = const Value.absent(),
    this.videoMaxSeconds = const Value.absent(),
    this.localeTag = const Value.absent(),
    this.warmupSets = const Value.absent(),
    this.advancedProgramming = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    this.weightUnit = const Value.absent(),
    this.activeRoutineId = const Value.absent(),
    this.layoffDays = const Value.absent(),
    this.layoffPercent = const Value.absent(),
    this.plateInventory = const Value.absent(),
    this.plateInventoryLb = const Value.absent(),
    this.barWeight = const Value.absent(),
    this.tutorialSeen = const Value.absent(),
    this.textScale = const Value.absent(),
    this.themePresetId = const Value.absent(),
    this.videoHeight = const Value.absent(),
    this.videoMaxSeconds = const Value.absent(),
    this.localeTag = const Value.absent(),
    this.warmupSets = const Value.absent(),
    this.advancedProgramming = const Value.absent(),
  });
  static Insertable<Setting> custom({
    Expression<int>? id,
    Expression<String>? weightUnit,
    Expression<int>? activeRoutineId,
    Expression<int>? layoffDays,
    Expression<int>? layoffPercent,
    Expression<String>? plateInventory,
    Expression<String>? plateInventoryLb,
    Expression<double>? barWeight,
    Expression<bool>? tutorialSeen,
    Expression<double>? textScale,
    Expression<String>? themePresetId,
    Expression<int>? videoHeight,
    Expression<int>? videoMaxSeconds,
    Expression<String>? localeTag,
    Expression<int>? warmupSets,
    Expression<bool>? advancedProgramming,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (weightUnit != null) 'weight_unit': weightUnit,
      if (activeRoutineId != null) 'active_routine_id': activeRoutineId,
      if (layoffDays != null) 'layoff_days': layoffDays,
      if (layoffPercent != null) 'layoff_percent': layoffPercent,
      if (plateInventory != null) 'plate_inventory': plateInventory,
      if (plateInventoryLb != null) 'plate_inventory_lb': plateInventoryLb,
      if (barWeight != null) 'bar_weight': barWeight,
      if (tutorialSeen != null) 'tutorial_seen': tutorialSeen,
      if (textScale != null) 'text_scale': textScale,
      if (themePresetId != null) 'theme_preset_id': themePresetId,
      if (videoHeight != null) 'video_height': videoHeight,
      if (videoMaxSeconds != null) 'video_max_seconds': videoMaxSeconds,
      if (localeTag != null) 'locale_tag': localeTag,
      if (warmupSets != null) 'warmup_sets': warmupSets,
      if (advancedProgramming != null)
        'advanced_programming': advancedProgramming,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<String?>? weightUnit,
    Value<int?>? activeRoutineId,
    Value<int>? layoffDays,
    Value<int>? layoffPercent,
    Value<String?>? plateInventory,
    Value<String?>? plateInventoryLb,
    Value<double?>? barWeight,
    Value<bool>? tutorialSeen,
    Value<double>? textScale,
    Value<String?>? themePresetId,
    Value<int>? videoHeight,
    Value<int>? videoMaxSeconds,
    Value<String?>? localeTag,
    Value<int>? warmupSets,
    Value<bool>? advancedProgramming,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      weightUnit: weightUnit ?? this.weightUnit,
      activeRoutineId: activeRoutineId ?? this.activeRoutineId,
      layoffDays: layoffDays ?? this.layoffDays,
      layoffPercent: layoffPercent ?? this.layoffPercent,
      plateInventory: plateInventory ?? this.plateInventory,
      plateInventoryLb: plateInventoryLb ?? this.plateInventoryLb,
      barWeight: barWeight ?? this.barWeight,
      tutorialSeen: tutorialSeen ?? this.tutorialSeen,
      textScale: textScale ?? this.textScale,
      themePresetId: themePresetId ?? this.themePresetId,
      videoHeight: videoHeight ?? this.videoHeight,
      videoMaxSeconds: videoMaxSeconds ?? this.videoMaxSeconds,
      localeTag: localeTag ?? this.localeTag,
      warmupSets: warmupSets ?? this.warmupSets,
      advancedProgramming: advancedProgramming ?? this.advancedProgramming,
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
    if (layoffDays.present) {
      map['layoff_days'] = Variable<int>(layoffDays.value);
    }
    if (layoffPercent.present) {
      map['layoff_percent'] = Variable<int>(layoffPercent.value);
    }
    if (plateInventory.present) {
      map['plate_inventory'] = Variable<String>(plateInventory.value);
    }
    if (plateInventoryLb.present) {
      map['plate_inventory_lb'] = Variable<String>(plateInventoryLb.value);
    }
    if (barWeight.present) {
      map['bar_weight'] = Variable<double>(barWeight.value);
    }
    if (tutorialSeen.present) {
      map['tutorial_seen'] = Variable<bool>(tutorialSeen.value);
    }
    if (textScale.present) {
      map['text_scale'] = Variable<double>(textScale.value);
    }
    if (themePresetId.present) {
      map['theme_preset_id'] = Variable<String>(themePresetId.value);
    }
    if (videoHeight.present) {
      map['video_height'] = Variable<int>(videoHeight.value);
    }
    if (videoMaxSeconds.present) {
      map['video_max_seconds'] = Variable<int>(videoMaxSeconds.value);
    }
    if (localeTag.present) {
      map['locale_tag'] = Variable<String>(localeTag.value);
    }
    if (warmupSets.present) {
      map['warmup_sets'] = Variable<int>(warmupSets.value);
    }
    if (advancedProgramming.present) {
      map['advanced_programming'] = Variable<bool>(advancedProgramming.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('weightUnit: $weightUnit, ')
          ..write('activeRoutineId: $activeRoutineId, ')
          ..write('layoffDays: $layoffDays, ')
          ..write('layoffPercent: $layoffPercent, ')
          ..write('plateInventory: $plateInventory, ')
          ..write('plateInventoryLb: $plateInventoryLb, ')
          ..write('barWeight: $barWeight, ')
          ..write('tutorialSeen: $tutorialSeen, ')
          ..write('textScale: $textScale, ')
          ..write('themePresetId: $themePresetId, ')
          ..write('videoHeight: $videoHeight, ')
          ..write('videoMaxSeconds: $videoMaxSeconds, ')
          ..write('localeTag: $localeTag, ')
          ..write('warmupSets: $warmupSets, ')
          ..write('advancedProgramming: $advancedProgramming')
          ..write(')'))
        .toString();
  }
}

class $CustomThemesTable extends CustomThemes
    with TableInfo<$CustomThemesTable, CustomTheme> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomThemesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _paletteMeta = const VerificationMeta(
    'palette',
  );
  @override
  late final GeneratedColumn<String> palette = GeneratedColumn<String>(
    'palette',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, palette];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_themes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomTheme> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('palette')) {
      context.handle(
        _paletteMeta,
        palette.isAcceptableOrUnknown(data['palette']!, _paletteMeta),
      );
    } else if (isInserting) {
      context.missing(_paletteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomTheme map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomTheme(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      palette: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}palette'],
      )!,
    );
  }

  @override
  $CustomThemesTable createAlias(String alias) {
    return $CustomThemesTable(attachedDatabase, alias);
  }
}

class CustomTheme extends DataClass implements Insertable<CustomTheme> {
  final int id;

  /// The palette as `AppPalette.toJson` writes it.
  final String palette;
  const CustomTheme({required this.id, required this.palette});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['palette'] = Variable<String>(palette);
    return map;
  }

  CustomThemesCompanion toCompanion(bool nullToAbsent) {
    return CustomThemesCompanion(id: Value(id), palette: Value(palette));
  }

  factory CustomTheme.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomTheme(
      id: serializer.fromJson<int>(json['id']),
      palette: serializer.fromJson<String>(json['palette']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'palette': serializer.toJson<String>(palette),
    };
  }

  CustomTheme copyWith({int? id, String? palette}) =>
      CustomTheme(id: id ?? this.id, palette: palette ?? this.palette);
  CustomTheme copyWithCompanion(CustomThemesCompanion data) {
    return CustomTheme(
      id: data.id.present ? data.id.value : this.id,
      palette: data.palette.present ? data.palette.value : this.palette,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomTheme(')
          ..write('id: $id, ')
          ..write('palette: $palette')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, palette);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomTheme &&
          other.id == this.id &&
          other.palette == this.palette);
}

class CustomThemesCompanion extends UpdateCompanion<CustomTheme> {
  final Value<int> id;
  final Value<String> palette;
  const CustomThemesCompanion({
    this.id = const Value.absent(),
    this.palette = const Value.absent(),
  });
  CustomThemesCompanion.insert({
    this.id = const Value.absent(),
    required String palette,
  }) : palette = Value(palette);
  static Insertable<CustomTheme> custom({
    Expression<int>? id,
    Expression<String>? palette,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (palette != null) 'palette': palette,
    });
  }

  CustomThemesCompanion copyWith({Value<int>? id, Value<String>? palette}) {
    return CustomThemesCompanion(
      id: id ?? this.id,
      palette: palette ?? this.palette,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (palette.present) {
      map['palette'] = Variable<String>(palette.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomThemesCompanion(')
          ..write('id: $id, ')
          ..write('palette: $palette')
          ..write(')'))
        .toString();
  }
}

class $LiveSessionsTable extends LiveSessions
    with TableInfo<$LiveSessionsTable, LiveSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LiveSessionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, payload, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'live_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LiveSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LiveSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LiveSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $LiveSessionsTable createAlias(String alias) {
    return $LiveSessionsTable(attachedDatabase, alias);
  }
}

class LiveSession extends DataClass implements Insertable<LiveSession> {
  /// Always 1. One session can be live at a time, so the row is a slot.
  final int id;

  /// The session as `encodeSession` writes it.
  final String payload;

  /// When the snapshot was taken, which is what the clocks are rebuilt against:
  /// the workout's elapsed time and any running rest both have to account for
  /// however long the app was dead. See `decodeSession`.
  final DateTime savedAt;
  const LiveSession({
    required this.id,
    required this.payload,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['payload'] = Variable<String>(payload);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  LiveSessionsCompanion toCompanion(bool nullToAbsent) {
    return LiveSessionsCompanion(
      id: Value(id),
      payload: Value(payload),
      savedAt: Value(savedAt),
    );
  }

  factory LiveSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LiveSession(
      id: serializer.fromJson<int>(json['id']),
      payload: serializer.fromJson<String>(json['payload']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'payload': serializer.toJson<String>(payload),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  LiveSession copyWith({int? id, String? payload, DateTime? savedAt}) =>
      LiveSession(
        id: id ?? this.id,
        payload: payload ?? this.payload,
        savedAt: savedAt ?? this.savedAt,
      );
  LiveSession copyWithCompanion(LiveSessionsCompanion data) {
    return LiveSession(
      id: data.id.present ? data.id.value : this.id,
      payload: data.payload.present ? data.payload.value : this.payload,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LiveSession(')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, payload, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LiveSession &&
          other.id == this.id &&
          other.payload == this.payload &&
          other.savedAt == this.savedAt);
}

class LiveSessionsCompanion extends UpdateCompanion<LiveSession> {
  final Value<int> id;
  final Value<String> payload;
  final Value<DateTime> savedAt;
  const LiveSessionsCompanion({
    this.id = const Value.absent(),
    this.payload = const Value.absent(),
    this.savedAt = const Value.absent(),
  });
  LiveSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String payload,
    required DateTime savedAt,
  }) : payload = Value(payload),
       savedAt = Value(savedAt);
  static Insertable<LiveSession> custom({
    Expression<int>? id,
    Expression<String>? payload,
    Expression<DateTime>? savedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payload != null) 'payload': payload,
      if (savedAt != null) 'saved_at': savedAt,
    });
  }

  LiveSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? payload,
    Value<DateTime>? savedAt,
  }) {
    return LiveSessionsCompanion(
      id: id ?? this.id,
      payload: payload ?? this.payload,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LiveSessionsCompanion(')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }
}

class $BarsTable extends Bars with TableInfo<$BarsTable, Bar> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BarsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 2,
      maxTextLength: 2,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seedKeyMeta = const VerificationMeta(
    'seedKey',
  );
  @override
  late final GeneratedColumn<String> seedKey = GeneratedColumn<String>(
    'seed_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
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
    unit,
    name,
    seedKey,
    weightKg,
    isCustom,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bars';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bar> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('seed_key')) {
      context.handle(
        _seedKeyMeta,
        seedKey.isAcceptableOrUnknown(data['seed_key']!, _seedKeyMeta),
      );
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    } else if (isInserting) {
      context.missing(_weightKgMeta);
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
  Bar map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bar(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      seedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seed_key'],
      ),
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      )!,
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
    );
  }

  @override
  $BarsTable createAlias(String alias) {
    return $BarsTable(attachedDatabase, alias);
  }
}

class Bar extends DataClass implements Insertable<Bar> {
  final int id;

  /// `kg` or `lb` — which unit's list this bar is on.
  final String unit;
  final String name;

  /// Which of the bars the app ships with this is, or null for one you added.
  ///
  /// The seeded bars are fixed — [isCustom] false, unrenameable — so unlike a
  /// routine or a training day this key is never cleared. See
  /// `util/seed_names.dart`.
  final String? seedKey;

  /// What the bar weighs, in kilograms.
  final double weightKg;

  /// Whether you added this bar. False for the seeded ones, which are fixed —
  /// see the class comment.
  final bool isCustom;
  const Bar({
    required this.id,
    required this.unit,
    required this.name,
    this.seedKey,
    required this.weightKg,
    required this.isCustom,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['unit'] = Variable<String>(unit);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || seedKey != null) {
      map['seed_key'] = Variable<String>(seedKey);
    }
    map['weight_kg'] = Variable<double>(weightKg);
    map['is_custom'] = Variable<bool>(isCustom);
    return map;
  }

  BarsCompanion toCompanion(bool nullToAbsent) {
    return BarsCompanion(
      id: Value(id),
      unit: Value(unit),
      name: Value(name),
      seedKey: seedKey == null && nullToAbsent
          ? const Value.absent()
          : Value(seedKey),
      weightKg: Value(weightKg),
      isCustom: Value(isCustom),
    );
  }

  factory Bar.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bar(
      id: serializer.fromJson<int>(json['id']),
      unit: serializer.fromJson<String>(json['unit']),
      name: serializer.fromJson<String>(json['name']),
      seedKey: serializer.fromJson<String?>(json['seedKey']),
      weightKg: serializer.fromJson<double>(json['weightKg']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'unit': serializer.toJson<String>(unit),
      'name': serializer.toJson<String>(name),
      'seedKey': serializer.toJson<String?>(seedKey),
      'weightKg': serializer.toJson<double>(weightKg),
      'isCustom': serializer.toJson<bool>(isCustom),
    };
  }

  Bar copyWith({
    int? id,
    String? unit,
    String? name,
    Value<String?> seedKey = const Value.absent(),
    double? weightKg,
    bool? isCustom,
  }) => Bar(
    id: id ?? this.id,
    unit: unit ?? this.unit,
    name: name ?? this.name,
    seedKey: seedKey.present ? seedKey.value : this.seedKey,
    weightKg: weightKg ?? this.weightKg,
    isCustom: isCustom ?? this.isCustom,
  );
  Bar copyWithCompanion(BarsCompanion data) {
    return Bar(
      id: data.id.present ? data.id.value : this.id,
      unit: data.unit.present ? data.unit.value : this.unit,
      name: data.name.present ? data.name.value : this.name,
      seedKey: data.seedKey.present ? data.seedKey.value : this.seedKey,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bar(')
          ..write('id: $id, ')
          ..write('unit: $unit, ')
          ..write('name: $name, ')
          ..write('seedKey: $seedKey, ')
          ..write('weightKg: $weightKg, ')
          ..write('isCustom: $isCustom')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, unit, name, seedKey, weightKg, isCustom);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bar &&
          other.id == this.id &&
          other.unit == this.unit &&
          other.name == this.name &&
          other.seedKey == this.seedKey &&
          other.weightKg == this.weightKg &&
          other.isCustom == this.isCustom);
}

class BarsCompanion extends UpdateCompanion<Bar> {
  final Value<int> id;
  final Value<String> unit;
  final Value<String> name;
  final Value<String?> seedKey;
  final Value<double> weightKg;
  final Value<bool> isCustom;
  const BarsCompanion({
    this.id = const Value.absent(),
    this.unit = const Value.absent(),
    this.name = const Value.absent(),
    this.seedKey = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.isCustom = const Value.absent(),
  });
  BarsCompanion.insert({
    this.id = const Value.absent(),
    required String unit,
    required String name,
    this.seedKey = const Value.absent(),
    required double weightKg,
    this.isCustom = const Value.absent(),
  }) : unit = Value(unit),
       name = Value(name),
       weightKg = Value(weightKg);
  static Insertable<Bar> custom({
    Expression<int>? id,
    Expression<String>? unit,
    Expression<String>? name,
    Expression<String>? seedKey,
    Expression<double>? weightKg,
    Expression<bool>? isCustom,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (unit != null) 'unit': unit,
      if (name != null) 'name': name,
      if (seedKey != null) 'seed_key': seedKey,
      if (weightKg != null) 'weight_kg': weightKg,
      if (isCustom != null) 'is_custom': isCustom,
    });
  }

  BarsCompanion copyWith({
    Value<int>? id,
    Value<String>? unit,
    Value<String>? name,
    Value<String?>? seedKey,
    Value<double>? weightKg,
    Value<bool>? isCustom,
  }) {
    return BarsCompanion(
      id: id ?? this.id,
      unit: unit ?? this.unit,
      name: name ?? this.name,
      seedKey: seedKey ?? this.seedKey,
      weightKg: weightKg ?? this.weightKg,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (seedKey.present) {
      map['seed_key'] = Variable<String>(seedKey.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BarsCompanion(')
          ..write('id: $id, ')
          ..write('unit: $unit, ')
          ..write('name: $name, ')
          ..write('seedKey: $seedKey, ')
          ..write('weightKg: $weightKg, ')
          ..write('isCustom: $isCustom')
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
  late final $CustomThemesTable customThemes = $CustomThemesTable(this);
  late final $LiveSessionsTable liveSessions = $LiveSessionsTable(this);
  late final $BarsTable bars = $BarsTable(this);
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
    customThemes,
    liveSessions,
    bars,
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
      Value<String?> seedKey,
      Value<String> muscleGroup,
      Value<String> equipment,
      Value<String?> videoUrl,
      Value<bool> isCustom,
      Value<ExerciseMeasure> measure,
      Value<WeightType> weightType,
      Value<String?> notes,
      Value<double?> barWeight,
      Value<String> extraPrimaryGroups,
      Value<String> secondaryGroups,
      Value<String?> unitOverride,
      Value<int?> warmupSets,
    });
typedef $$ExercisesTableUpdateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> seedKey,
      Value<String> muscleGroup,
      Value<String> equipment,
      Value<String?> videoUrl,
      Value<bool> isCustom,
      Value<ExerciseMeasure> measure,
      Value<WeightType> weightType,
      Value<String?> notes,
      Value<double?> barWeight,
      Value<String> extraPrimaryGroups,
      Value<String> secondaryGroups,
      Value<String?> unitOverride,
      Value<int?> warmupSets,
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

  ColumnFilters<String> get seedKey => $composableBuilder(
    column: $table.seedKey,
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

  ColumnFilters<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ExerciseMeasure, ExerciseMeasure, String>
  get measure => $composableBuilder(
    column: $table.measure,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<WeightType, WeightType, String>
  get weightType => $composableBuilder(
    column: $table.weightType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get barWeight => $composableBuilder(
    column: $table.barWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extraPrimaryGroups => $composableBuilder(
    column: $table.extraPrimaryGroups,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryGroups => $composableBuilder(
    column: $table.secondaryGroups,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitOverride => $composableBuilder(
    column: $table.unitOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get warmupSets => $composableBuilder(
    column: $table.warmupSets,
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

  ColumnOrderings<String> get seedKey => $composableBuilder(
    column: $table.seedKey,
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

  ColumnOrderings<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get measure => $composableBuilder(
    column: $table.measure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weightType => $composableBuilder(
    column: $table.weightType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get barWeight => $composableBuilder(
    column: $table.barWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraPrimaryGroups => $composableBuilder(
    column: $table.extraPrimaryGroups,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryGroups => $composableBuilder(
    column: $table.secondaryGroups,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitOverride => $composableBuilder(
    column: $table.unitOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get warmupSets => $composableBuilder(
    column: $table.warmupSets,
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

  GeneratedColumn<String> get seedKey =>
      $composableBuilder(column: $table.seedKey, builder: (column) => column);

  GeneratedColumn<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get equipment =>
      $composableBuilder(column: $table.equipment, builder: (column) => column);

  GeneratedColumn<String> get videoUrl =>
      $composableBuilder(column: $table.videoUrl, builder: (column) => column);

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ExerciseMeasure, String> get measure =>
      $composableBuilder(column: $table.measure, builder: (column) => column);

  GeneratedColumnWithTypeConverter<WeightType, String> get weightType =>
      $composableBuilder(
        column: $table.weightType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<double> get barWeight =>
      $composableBuilder(column: $table.barWeight, builder: (column) => column);

  GeneratedColumn<String> get extraPrimaryGroups => $composableBuilder(
    column: $table.extraPrimaryGroups,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secondaryGroups => $composableBuilder(
    column: $table.secondaryGroups,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unitOverride => $composableBuilder(
    column: $table.unitOverride,
    builder: (column) => column,
  );

  GeneratedColumn<int> get warmupSets => $composableBuilder(
    column: $table.warmupSets,
    builder: (column) => column,
  );

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
                Value<String?> seedKey = const Value.absent(),
                Value<String> muscleGroup = const Value.absent(),
                Value<String> equipment = const Value.absent(),
                Value<String?> videoUrl = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<ExerciseMeasure> measure = const Value.absent(),
                Value<WeightType> weightType = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<double?> barWeight = const Value.absent(),
                Value<String> extraPrimaryGroups = const Value.absent(),
                Value<String> secondaryGroups = const Value.absent(),
                Value<String?> unitOverride = const Value.absent(),
                Value<int?> warmupSets = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                name: name,
                seedKey: seedKey,
                muscleGroup: muscleGroup,
                equipment: equipment,
                videoUrl: videoUrl,
                isCustom: isCustom,
                measure: measure,
                weightType: weightType,
                notes: notes,
                barWeight: barWeight,
                extraPrimaryGroups: extraPrimaryGroups,
                secondaryGroups: secondaryGroups,
                unitOverride: unitOverride,
                warmupSets: warmupSets,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> seedKey = const Value.absent(),
                Value<String> muscleGroup = const Value.absent(),
                Value<String> equipment = const Value.absent(),
                Value<String?> videoUrl = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<ExerciseMeasure> measure = const Value.absent(),
                Value<WeightType> weightType = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<double?> barWeight = const Value.absent(),
                Value<String> extraPrimaryGroups = const Value.absent(),
                Value<String> secondaryGroups = const Value.absent(),
                Value<String?> unitOverride = const Value.absent(),
                Value<int?> warmupSets = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                name: name,
                seedKey: seedKey,
                muscleGroup: muscleGroup,
                equipment: equipment,
                videoUrl: videoUrl,
                isCustom: isCustom,
                measure: measure,
                weightType: weightType,
                notes: notes,
                barWeight: barWeight,
                extraPrimaryGroups: extraPrimaryGroups,
                secondaryGroups: secondaryGroups,
                unitOverride: unitOverride,
                warmupSets: warmupSets,
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
      Value<String?> seedKey,
      Value<String> colorHex,
      Value<int> position,
      Value<int> restSeconds,
      Value<int> scheduleDays,
      Value<int?> reminderMinutes,
      Value<String?> description,
    });
typedef $$RoutinesTableUpdateCompanionBuilder =
    RoutinesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> seedKey,
      Value<String> colorHex,
      Value<int> position,
      Value<int> restSeconds,
      Value<int> scheduleDays,
      Value<int?> reminderMinutes,
      Value<String?> description,
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

  ColumnFilters<String> get seedKey => $composableBuilder(
    column: $table.seedKey,
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

  ColumnFilters<int> get scheduleDays => $composableBuilder(
    column: $table.scheduleDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
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

  ColumnOrderings<String> get seedKey => $composableBuilder(
    column: $table.seedKey,
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

  ColumnOrderings<int> get scheduleDays => $composableBuilder(
    column: $table.scheduleDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
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

  GeneratedColumn<String> get seedKey =>
      $composableBuilder(column: $table.seedKey, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduleDays => $composableBuilder(
    column: $table.scheduleDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
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
                Value<String?> seedKey = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> restSeconds = const Value.absent(),
                Value<int> scheduleDays = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<String?> description = const Value.absent(),
              }) => RoutinesCompanion(
                id: id,
                name: name,
                seedKey: seedKey,
                colorHex: colorHex,
                position: position,
                restSeconds: restSeconds,
                scheduleDays: scheduleDays,
                reminderMinutes: reminderMinutes,
                description: description,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> seedKey = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> restSeconds = const Value.absent(),
                Value<int> scheduleDays = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<String?> description = const Value.absent(),
              }) => RoutinesCompanion.insert(
                id: id,
                name: name,
                seedKey: seedKey,
                colorHex: colorHex,
                position: position,
                restSeconds: restSeconds,
                scheduleDays: scheduleDays,
                reminderMinutes: reminderMinutes,
                description: description,
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
      Value<String?> seedKey,
      Value<int> position,
      Value<bool> warmupsEnabled,
    });
typedef $$WorkoutsTableUpdateCompanionBuilder =
    WorkoutsCompanion Function({
      Value<int> id,
      Value<int> routineId,
      Value<String> name,
      Value<String?> seedKey,
      Value<int> position,
      Value<bool> warmupsEnabled,
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

  ColumnFilters<String> get seedKey => $composableBuilder(
    column: $table.seedKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get warmupsEnabled => $composableBuilder(
    column: $table.warmupsEnabled,
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

  ColumnOrderings<String> get seedKey => $composableBuilder(
    column: $table.seedKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get warmupsEnabled => $composableBuilder(
    column: $table.warmupsEnabled,
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

  GeneratedColumn<String> get seedKey =>
      $composableBuilder(column: $table.seedKey, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get warmupsEnabled => $composableBuilder(
    column: $table.warmupsEnabled,
    builder: (column) => column,
  );

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
                Value<String?> seedKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> warmupsEnabled = const Value.absent(),
              }) => WorkoutsCompanion(
                id: id,
                routineId: routineId,
                name: name,
                seedKey: seedKey,
                position: position,
                warmupsEnabled: warmupsEnabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int routineId,
                required String name,
                Value<String?> seedKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> warmupsEnabled = const Value.absent(),
              }) => WorkoutsCompanion.insert(
                id: id,
                routineId: routineId,
                name: name,
                seedKey: seedKey,
                position: position,
                warmupsEnabled: warmupsEnabled,
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
      Value<SetScheme> scheme,
      Value<int> schemePercent,
      Value<String?> customSets,
      Value<ProgressionMode> progression,
      Value<int> holdSeconds,
      Value<double> increment,
      Value<int> successThreshold,
      Value<double> deload,
      Value<int> failureThreshold,
      Value<int> successStreak,
      Value<int> failStreak,
      Value<bool> supersetWithPrevious,
      Value<bool> addWeightAtTopOfRange,
      Value<double> repsIncrement,
      Value<double> repsDeload,
      Value<int?> repsTarget,
      Value<String?> sparedRates,
      Value<String?> cycleBlocks,
      Value<int> cyclePosition,
      Value<String?> cycleNames,
      Value<int?> targetRpe,
      Value<GzclTier?> gzclTier,
      Value<String?> gzclStages,
      Value<int> gzclStage,
      Value<int> gzclAmrapTarget,
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
      Value<SetScheme> scheme,
      Value<int> schemePercent,
      Value<String?> customSets,
      Value<ProgressionMode> progression,
      Value<int> holdSeconds,
      Value<double> increment,
      Value<int> successThreshold,
      Value<double> deload,
      Value<int> failureThreshold,
      Value<int> successStreak,
      Value<int> failStreak,
      Value<bool> supersetWithPrevious,
      Value<bool> addWeightAtTopOfRange,
      Value<double> repsIncrement,
      Value<double> repsDeload,
      Value<int?> repsTarget,
      Value<String?> sparedRates,
      Value<String?> cycleBlocks,
      Value<int> cyclePosition,
      Value<String?> cycleNames,
      Value<int?> targetRpe,
      Value<GzclTier?> gzclTier,
      Value<String?> gzclStages,
      Value<int> gzclStage,
      Value<int> gzclAmrapTarget,
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

  ColumnWithTypeConverterFilters<SetScheme, SetScheme, String> get scheme =>
      $composableBuilder(
        column: $table.scheme,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get schemePercent => $composableBuilder(
    column: $table.schemePercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customSets => $composableBuilder(
    column: $table.customSets,
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

  ColumnFilters<bool> get supersetWithPrevious => $composableBuilder(
    column: $table.supersetWithPrevious,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get addWeightAtTopOfRange => $composableBuilder(
    column: $table.addWeightAtTopOfRange,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get repsIncrement => $composableBuilder(
    column: $table.repsIncrement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get repsDeload => $composableBuilder(
    column: $table.repsDeload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repsTarget => $composableBuilder(
    column: $table.repsTarget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sparedRates => $composableBuilder(
    column: $table.sparedRates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cycleBlocks => $composableBuilder(
    column: $table.cycleBlocks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cyclePosition => $composableBuilder(
    column: $table.cyclePosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cycleNames => $composableBuilder(
    column: $table.cycleNames,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetRpe => $composableBuilder(
    column: $table.targetRpe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<GzclTier?, GzclTier, String> get gzclTier =>
      $composableBuilder(
        column: $table.gzclTier,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get gzclStages => $composableBuilder(
    column: $table.gzclStages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gzclStage => $composableBuilder(
    column: $table.gzclStage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gzclAmrapTarget => $composableBuilder(
    column: $table.gzclAmrapTarget,
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

  ColumnOrderings<String> get scheme => $composableBuilder(
    column: $table.scheme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemePercent => $composableBuilder(
    column: $table.schemePercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customSets => $composableBuilder(
    column: $table.customSets,
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

  ColumnOrderings<bool> get supersetWithPrevious => $composableBuilder(
    column: $table.supersetWithPrevious,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get addWeightAtTopOfRange => $composableBuilder(
    column: $table.addWeightAtTopOfRange,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get repsIncrement => $composableBuilder(
    column: $table.repsIncrement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get repsDeload => $composableBuilder(
    column: $table.repsDeload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repsTarget => $composableBuilder(
    column: $table.repsTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sparedRates => $composableBuilder(
    column: $table.sparedRates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cycleBlocks => $composableBuilder(
    column: $table.cycleBlocks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cyclePosition => $composableBuilder(
    column: $table.cyclePosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cycleNames => $composableBuilder(
    column: $table.cycleNames,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetRpe => $composableBuilder(
    column: $table.targetRpe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gzclTier => $composableBuilder(
    column: $table.gzclTier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gzclStages => $composableBuilder(
    column: $table.gzclStages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gzclStage => $composableBuilder(
    column: $table.gzclStage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gzclAmrapTarget => $composableBuilder(
    column: $table.gzclAmrapTarget,
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

  GeneratedColumnWithTypeConverter<SetScheme, String> get scheme =>
      $composableBuilder(column: $table.scheme, builder: (column) => column);

  GeneratedColumn<int> get schemePercent => $composableBuilder(
    column: $table.schemePercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customSets => $composableBuilder(
    column: $table.customSets,
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

  GeneratedColumn<bool> get supersetWithPrevious => $composableBuilder(
    column: $table.supersetWithPrevious,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get addWeightAtTopOfRange => $composableBuilder(
    column: $table.addWeightAtTopOfRange,
    builder: (column) => column,
  );

  GeneratedColumn<double> get repsIncrement => $composableBuilder(
    column: $table.repsIncrement,
    builder: (column) => column,
  );

  GeneratedColumn<double> get repsDeload => $composableBuilder(
    column: $table.repsDeload,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repsTarget => $composableBuilder(
    column: $table.repsTarget,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sparedRates => $composableBuilder(
    column: $table.sparedRates,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cycleBlocks => $composableBuilder(
    column: $table.cycleBlocks,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cyclePosition => $composableBuilder(
    column: $table.cyclePosition,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cycleNames => $composableBuilder(
    column: $table.cycleNames,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetRpe =>
      $composableBuilder(column: $table.targetRpe, builder: (column) => column);

  GeneratedColumnWithTypeConverter<GzclTier?, String> get gzclTier =>
      $composableBuilder(column: $table.gzclTier, builder: (column) => column);

  GeneratedColumn<String> get gzclStages => $composableBuilder(
    column: $table.gzclStages,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gzclStage =>
      $composableBuilder(column: $table.gzclStage, builder: (column) => column);

  GeneratedColumn<int> get gzclAmrapTarget => $composableBuilder(
    column: $table.gzclAmrapTarget,
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
                Value<SetScheme> scheme = const Value.absent(),
                Value<int> schemePercent = const Value.absent(),
                Value<String?> customSets = const Value.absent(),
                Value<ProgressionMode> progression = const Value.absent(),
                Value<int> holdSeconds = const Value.absent(),
                Value<double> increment = const Value.absent(),
                Value<int> successThreshold = const Value.absent(),
                Value<double> deload = const Value.absent(),
                Value<int> failureThreshold = const Value.absent(),
                Value<int> successStreak = const Value.absent(),
                Value<int> failStreak = const Value.absent(),
                Value<bool> supersetWithPrevious = const Value.absent(),
                Value<bool> addWeightAtTopOfRange = const Value.absent(),
                Value<double> repsIncrement = const Value.absent(),
                Value<double> repsDeload = const Value.absent(),
                Value<int?> repsTarget = const Value.absent(),
                Value<String?> sparedRates = const Value.absent(),
                Value<String?> cycleBlocks = const Value.absent(),
                Value<int> cyclePosition = const Value.absent(),
                Value<String?> cycleNames = const Value.absent(),
                Value<int?> targetRpe = const Value.absent(),
                Value<GzclTier?> gzclTier = const Value.absent(),
                Value<String?> gzclStages = const Value.absent(),
                Value<int> gzclStage = const Value.absent(),
                Value<int> gzclAmrapTarget = const Value.absent(),
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
                scheme: scheme,
                schemePercent: schemePercent,
                customSets: customSets,
                progression: progression,
                holdSeconds: holdSeconds,
                increment: increment,
                successThreshold: successThreshold,
                deload: deload,
                failureThreshold: failureThreshold,
                successStreak: successStreak,
                failStreak: failStreak,
                supersetWithPrevious: supersetWithPrevious,
                addWeightAtTopOfRange: addWeightAtTopOfRange,
                repsIncrement: repsIncrement,
                repsDeload: repsDeload,
                repsTarget: repsTarget,
                sparedRates: sparedRates,
                cycleBlocks: cycleBlocks,
                cyclePosition: cyclePosition,
                cycleNames: cycleNames,
                targetRpe: targetRpe,
                gzclTier: gzclTier,
                gzclStages: gzclStages,
                gzclStage: gzclStage,
                gzclAmrapTarget: gzclAmrapTarget,
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
                Value<SetScheme> scheme = const Value.absent(),
                Value<int> schemePercent = const Value.absent(),
                Value<String?> customSets = const Value.absent(),
                Value<ProgressionMode> progression = const Value.absent(),
                Value<int> holdSeconds = const Value.absent(),
                Value<double> increment = const Value.absent(),
                Value<int> successThreshold = const Value.absent(),
                Value<double> deload = const Value.absent(),
                Value<int> failureThreshold = const Value.absent(),
                Value<int> successStreak = const Value.absent(),
                Value<int> failStreak = const Value.absent(),
                Value<bool> supersetWithPrevious = const Value.absent(),
                Value<bool> addWeightAtTopOfRange = const Value.absent(),
                Value<double> repsIncrement = const Value.absent(),
                Value<double> repsDeload = const Value.absent(),
                Value<int?> repsTarget = const Value.absent(),
                Value<String?> sparedRates = const Value.absent(),
                Value<String?> cycleBlocks = const Value.absent(),
                Value<int> cyclePosition = const Value.absent(),
                Value<String?> cycleNames = const Value.absent(),
                Value<int?> targetRpe = const Value.absent(),
                Value<GzclTier?> gzclTier = const Value.absent(),
                Value<String?> gzclStages = const Value.absent(),
                Value<int> gzclStage = const Value.absent(),
                Value<int> gzclAmrapTarget = const Value.absent(),
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
                scheme: scheme,
                schemePercent: schemePercent,
                customSets: customSets,
                progression: progression,
                holdSeconds: holdSeconds,
                increment: increment,
                successThreshold: successThreshold,
                deload: deload,
                failureThreshold: failureThreshold,
                successStreak: successStreak,
                failStreak: failStreak,
                supersetWithPrevious: supersetWithPrevious,
                addWeightAtTopOfRange: addWeightAtTopOfRange,
                repsIncrement: repsIncrement,
                repsDeload: repsDeload,
                repsTarget: repsTarget,
                sparedRates: sparedRates,
                cycleBlocks: cycleBlocks,
                cyclePosition: cyclePosition,
                cycleNames: cycleNames,
                targetRpe: targetRpe,
                gzclTier: gzclTier,
                gzclStages: gzclStages,
                gzclStage: gzclStage,
                gzclAmrapTarget: gzclAmrapTarget,
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
      Value<String?> seedKey,
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
      Value<String?> seedKey,
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

  ColumnFilters<String> get seedKey => $composableBuilder(
    column: $table.seedKey,
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

  ColumnOrderings<String> get seedKey => $composableBuilder(
    column: $table.seedKey,
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

  GeneratedColumn<String> get seedKey =>
      $composableBuilder(column: $table.seedKey, builder: (column) => column);

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
                Value<String?> seedKey = const Value.absent(),
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
                seedKey: seedKey,
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
                Value<String?> seedKey = const Value.absent(),
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
                seedKey: seedKey,
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
      Value<String?> exerciseSeedKey,
      required int setNumber,
      Value<double> weight,
      Value<int> reps,
      Value<bool> done,
      Value<int> goalReps,
      Value<double?> goalWeight,
      Value<int?> seconds,
      Value<int?> goalSeconds,
      Value<String?> videoPath,
      Value<double?> speedKph,
      Value<double?> inclinePercent,
      Value<int?> resistanceLevel,
      Value<double?> distanceKm,
      Value<int?> actualRpe,
    });
typedef $$SessionSetsTableUpdateCompanionBuilder =
    SessionSetsCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<int?> exerciseId,
      Value<String> exerciseName,
      Value<String?> exerciseSeedKey,
      Value<int> setNumber,
      Value<double> weight,
      Value<int> reps,
      Value<bool> done,
      Value<int> goalReps,
      Value<double?> goalWeight,
      Value<int?> seconds,
      Value<int?> goalSeconds,
      Value<String?> videoPath,
      Value<double?> speedKph,
      Value<double?> inclinePercent,
      Value<int?> resistanceLevel,
      Value<double?> distanceKm,
      Value<int?> actualRpe,
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

  ColumnFilters<String> get exerciseSeedKey => $composableBuilder(
    column: $table.exerciseSeedKey,
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

  ColumnFilters<String> get videoPath => $composableBuilder(
    column: $table.videoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speedKph => $composableBuilder(
    column: $table.speedKph,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get inclinePercent => $composableBuilder(
    column: $table.inclinePercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resistanceLevel => $composableBuilder(
    column: $table.resistanceLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualRpe => $composableBuilder(
    column: $table.actualRpe,
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

  ColumnOrderings<String> get exerciseSeedKey => $composableBuilder(
    column: $table.exerciseSeedKey,
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

  ColumnOrderings<String> get videoPath => $composableBuilder(
    column: $table.videoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speedKph => $composableBuilder(
    column: $table.speedKph,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get inclinePercent => $composableBuilder(
    column: $table.inclinePercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resistanceLevel => $composableBuilder(
    column: $table.resistanceLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualRpe => $composableBuilder(
    column: $table.actualRpe,
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

  GeneratedColumn<String> get exerciseSeedKey => $composableBuilder(
    column: $table.exerciseSeedKey,
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

  GeneratedColumn<String> get videoPath =>
      $composableBuilder(column: $table.videoPath, builder: (column) => column);

  GeneratedColumn<double> get speedKph =>
      $composableBuilder(column: $table.speedKph, builder: (column) => column);

  GeneratedColumn<double> get inclinePercent => $composableBuilder(
    column: $table.inclinePercent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resistanceLevel => $composableBuilder(
    column: $table.resistanceLevel,
    builder: (column) => column,
  );

  GeneratedColumn<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualRpe =>
      $composableBuilder(column: $table.actualRpe, builder: (column) => column);

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
                Value<String?> exerciseSeedKey = const Value.absent(),
                Value<int> setNumber = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> goalReps = const Value.absent(),
                Value<double?> goalWeight = const Value.absent(),
                Value<int?> seconds = const Value.absent(),
                Value<int?> goalSeconds = const Value.absent(),
                Value<String?> videoPath = const Value.absent(),
                Value<double?> speedKph = const Value.absent(),
                Value<double?> inclinePercent = const Value.absent(),
                Value<int?> resistanceLevel = const Value.absent(),
                Value<double?> distanceKm = const Value.absent(),
                Value<int?> actualRpe = const Value.absent(),
              }) => SessionSetsCompanion(
                id: id,
                sessionId: sessionId,
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                exerciseSeedKey: exerciseSeedKey,
                setNumber: setNumber,
                weight: weight,
                reps: reps,
                done: done,
                goalReps: goalReps,
                goalWeight: goalWeight,
                seconds: seconds,
                goalSeconds: goalSeconds,
                videoPath: videoPath,
                speedKph: speedKph,
                inclinePercent: inclinePercent,
                resistanceLevel: resistanceLevel,
                distanceKm: distanceKm,
                actualRpe: actualRpe,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                Value<int?> exerciseId = const Value.absent(),
                required String exerciseName,
                Value<String?> exerciseSeedKey = const Value.absent(),
                required int setNumber,
                Value<double> weight = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<int> goalReps = const Value.absent(),
                Value<double?> goalWeight = const Value.absent(),
                Value<int?> seconds = const Value.absent(),
                Value<int?> goalSeconds = const Value.absent(),
                Value<String?> videoPath = const Value.absent(),
                Value<double?> speedKph = const Value.absent(),
                Value<double?> inclinePercent = const Value.absent(),
                Value<int?> resistanceLevel = const Value.absent(),
                Value<double?> distanceKm = const Value.absent(),
                Value<int?> actualRpe = const Value.absent(),
              }) => SessionSetsCompanion.insert(
                id: id,
                sessionId: sessionId,
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                exerciseSeedKey: exerciseSeedKey,
                setNumber: setNumber,
                weight: weight,
                reps: reps,
                done: done,
                goalReps: goalReps,
                goalWeight: goalWeight,
                seconds: seconds,
                goalSeconds: goalSeconds,
                videoPath: videoPath,
                speedKph: speedKph,
                inclinePercent: inclinePercent,
                resistanceLevel: resistanceLevel,
                distanceKm: distanceKm,
                actualRpe: actualRpe,
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
      Value<String?> weightUnit,
      Value<int?> activeRoutineId,
      Value<int> layoffDays,
      Value<int> layoffPercent,
      Value<String?> plateInventory,
      Value<String?> plateInventoryLb,
      Value<double?> barWeight,
      Value<bool> tutorialSeen,
      Value<double> textScale,
      Value<String?> themePresetId,
      Value<int> videoHeight,
      Value<int> videoMaxSeconds,
      Value<String?> localeTag,
      Value<int> warmupSets,
      Value<bool> advancedProgramming,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      Value<String?> weightUnit,
      Value<int?> activeRoutineId,
      Value<int> layoffDays,
      Value<int> layoffPercent,
      Value<String?> plateInventory,
      Value<String?> plateInventoryLb,
      Value<double?> barWeight,
      Value<bool> tutorialSeen,
      Value<double> textScale,
      Value<String?> themePresetId,
      Value<int> videoHeight,
      Value<int> videoMaxSeconds,
      Value<String?> localeTag,
      Value<int> warmupSets,
      Value<bool> advancedProgramming,
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

  ColumnFilters<int> get layoffDays => $composableBuilder(
    column: $table.layoffDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get layoffPercent => $composableBuilder(
    column: $table.layoffPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plateInventory => $composableBuilder(
    column: $table.plateInventory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plateInventoryLb => $composableBuilder(
    column: $table.plateInventoryLb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get barWeight => $composableBuilder(
    column: $table.barWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tutorialSeen => $composableBuilder(
    column: $table.tutorialSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get textScale => $composableBuilder(
    column: $table.textScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themePresetId => $composableBuilder(
    column: $table.themePresetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get videoHeight => $composableBuilder(
    column: $table.videoHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get videoMaxSeconds => $composableBuilder(
    column: $table.videoMaxSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localeTag => $composableBuilder(
    column: $table.localeTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get warmupSets => $composableBuilder(
    column: $table.warmupSets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get advancedProgramming => $composableBuilder(
    column: $table.advancedProgramming,
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

  ColumnOrderings<int> get layoffDays => $composableBuilder(
    column: $table.layoffDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get layoffPercent => $composableBuilder(
    column: $table.layoffPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plateInventory => $composableBuilder(
    column: $table.plateInventory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plateInventoryLb => $composableBuilder(
    column: $table.plateInventoryLb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get barWeight => $composableBuilder(
    column: $table.barWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tutorialSeen => $composableBuilder(
    column: $table.tutorialSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get textScale => $composableBuilder(
    column: $table.textScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themePresetId => $composableBuilder(
    column: $table.themePresetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get videoHeight => $composableBuilder(
    column: $table.videoHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get videoMaxSeconds => $composableBuilder(
    column: $table.videoMaxSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localeTag => $composableBuilder(
    column: $table.localeTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get warmupSets => $composableBuilder(
    column: $table.warmupSets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get advancedProgramming => $composableBuilder(
    column: $table.advancedProgramming,
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

  GeneratedColumn<int> get layoffDays => $composableBuilder(
    column: $table.layoffDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get layoffPercent => $composableBuilder(
    column: $table.layoffPercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plateInventory => $composableBuilder(
    column: $table.plateInventory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plateInventoryLb => $composableBuilder(
    column: $table.plateInventoryLb,
    builder: (column) => column,
  );

  GeneratedColumn<double> get barWeight =>
      $composableBuilder(column: $table.barWeight, builder: (column) => column);

  GeneratedColumn<bool> get tutorialSeen => $composableBuilder(
    column: $table.tutorialSeen,
    builder: (column) => column,
  );

  GeneratedColumn<double> get textScale =>
      $composableBuilder(column: $table.textScale, builder: (column) => column);

  GeneratedColumn<String> get themePresetId => $composableBuilder(
    column: $table.themePresetId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get videoHeight => $composableBuilder(
    column: $table.videoHeight,
    builder: (column) => column,
  );

  GeneratedColumn<int> get videoMaxSeconds => $composableBuilder(
    column: $table.videoMaxSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localeTag =>
      $composableBuilder(column: $table.localeTag, builder: (column) => column);

  GeneratedColumn<int> get warmupSets => $composableBuilder(
    column: $table.warmupSets,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get advancedProgramming => $composableBuilder(
    column: $table.advancedProgramming,
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
                Value<String?> weightUnit = const Value.absent(),
                Value<int?> activeRoutineId = const Value.absent(),
                Value<int> layoffDays = const Value.absent(),
                Value<int> layoffPercent = const Value.absent(),
                Value<String?> plateInventory = const Value.absent(),
                Value<String?> plateInventoryLb = const Value.absent(),
                Value<double?> barWeight = const Value.absent(),
                Value<bool> tutorialSeen = const Value.absent(),
                Value<double> textScale = const Value.absent(),
                Value<String?> themePresetId = const Value.absent(),
                Value<int> videoHeight = const Value.absent(),
                Value<int> videoMaxSeconds = const Value.absent(),
                Value<String?> localeTag = const Value.absent(),
                Value<int> warmupSets = const Value.absent(),
                Value<bool> advancedProgramming = const Value.absent(),
              }) => SettingsCompanion(
                id: id,
                weightUnit: weightUnit,
                activeRoutineId: activeRoutineId,
                layoffDays: layoffDays,
                layoffPercent: layoffPercent,
                plateInventory: plateInventory,
                plateInventoryLb: plateInventoryLb,
                barWeight: barWeight,
                tutorialSeen: tutorialSeen,
                textScale: textScale,
                themePresetId: themePresetId,
                videoHeight: videoHeight,
                videoMaxSeconds: videoMaxSeconds,
                localeTag: localeTag,
                warmupSets: warmupSets,
                advancedProgramming: advancedProgramming,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> weightUnit = const Value.absent(),
                Value<int?> activeRoutineId = const Value.absent(),
                Value<int> layoffDays = const Value.absent(),
                Value<int> layoffPercent = const Value.absent(),
                Value<String?> plateInventory = const Value.absent(),
                Value<String?> plateInventoryLb = const Value.absent(),
                Value<double?> barWeight = const Value.absent(),
                Value<bool> tutorialSeen = const Value.absent(),
                Value<double> textScale = const Value.absent(),
                Value<String?> themePresetId = const Value.absent(),
                Value<int> videoHeight = const Value.absent(),
                Value<int> videoMaxSeconds = const Value.absent(),
                Value<String?> localeTag = const Value.absent(),
                Value<int> warmupSets = const Value.absent(),
                Value<bool> advancedProgramming = const Value.absent(),
              }) => SettingsCompanion.insert(
                id: id,
                weightUnit: weightUnit,
                activeRoutineId: activeRoutineId,
                layoffDays: layoffDays,
                layoffPercent: layoffPercent,
                plateInventory: plateInventory,
                plateInventoryLb: plateInventoryLb,
                barWeight: barWeight,
                tutorialSeen: tutorialSeen,
                textScale: textScale,
                themePresetId: themePresetId,
                videoHeight: videoHeight,
                videoMaxSeconds: videoMaxSeconds,
                localeTag: localeTag,
                warmupSets: warmupSets,
                advancedProgramming: advancedProgramming,
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
typedef $$CustomThemesTableCreateCompanionBuilder =
    CustomThemesCompanion Function({Value<int> id, required String palette});
typedef $$CustomThemesTableUpdateCompanionBuilder =
    CustomThemesCompanion Function({Value<int> id, Value<String> palette});

class $$CustomThemesTableFilterComposer
    extends Composer<_$AppDatabase, $CustomThemesTable> {
  $$CustomThemesTableFilterComposer({
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

  ColumnFilters<String> get palette => $composableBuilder(
    column: $table.palette,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomThemesTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomThemesTable> {
  $$CustomThemesTableOrderingComposer({
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

  ColumnOrderings<String> get palette => $composableBuilder(
    column: $table.palette,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomThemesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomThemesTable> {
  $$CustomThemesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get palette =>
      $composableBuilder(column: $table.palette, builder: (column) => column);
}

class $$CustomThemesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomThemesTable,
          CustomTheme,
          $$CustomThemesTableFilterComposer,
          $$CustomThemesTableOrderingComposer,
          $$CustomThemesTableAnnotationComposer,
          $$CustomThemesTableCreateCompanionBuilder,
          $$CustomThemesTableUpdateCompanionBuilder,
          (
            CustomTheme,
            BaseReferences<_$AppDatabase, $CustomThemesTable, CustomTheme>,
          ),
          CustomTheme,
          PrefetchHooks Function()
        > {
  $$CustomThemesTableTableManager(_$AppDatabase db, $CustomThemesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomThemesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomThemesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomThemesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> palette = const Value.absent(),
              }) => CustomThemesCompanion(id: id, palette: palette),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String palette,
              }) => CustomThemesCompanion.insert(id: id, palette: palette),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomThemesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomThemesTable,
      CustomTheme,
      $$CustomThemesTableFilterComposer,
      $$CustomThemesTableOrderingComposer,
      $$CustomThemesTableAnnotationComposer,
      $$CustomThemesTableCreateCompanionBuilder,
      $$CustomThemesTableUpdateCompanionBuilder,
      (
        CustomTheme,
        BaseReferences<_$AppDatabase, $CustomThemesTable, CustomTheme>,
      ),
      CustomTheme,
      PrefetchHooks Function()
    >;
typedef $$LiveSessionsTableCreateCompanionBuilder =
    LiveSessionsCompanion Function({
      Value<int> id,
      required String payload,
      required DateTime savedAt,
    });
typedef $$LiveSessionsTableUpdateCompanionBuilder =
    LiveSessionsCompanion Function({
      Value<int> id,
      Value<String> payload,
      Value<DateTime> savedAt,
    });

class $$LiveSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $LiveSessionsTable> {
  $$LiveSessionsTableFilterComposer({
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

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LiveSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LiveSessionsTable> {
  $$LiveSessionsTableOrderingComposer({
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

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LiveSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LiveSessionsTable> {
  $$LiveSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$LiveSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LiveSessionsTable,
          LiveSession,
          $$LiveSessionsTableFilterComposer,
          $$LiveSessionsTableOrderingComposer,
          $$LiveSessionsTableAnnotationComposer,
          $$LiveSessionsTableCreateCompanionBuilder,
          $$LiveSessionsTableUpdateCompanionBuilder,
          (
            LiveSession,
            BaseReferences<_$AppDatabase, $LiveSessionsTable, LiveSession>,
          ),
          LiveSession,
          PrefetchHooks Function()
        > {
  $$LiveSessionsTableTableManager(_$AppDatabase db, $LiveSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LiveSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LiveSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LiveSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
              }) => LiveSessionsCompanion(
                id: id,
                payload: payload,
                savedAt: savedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String payload,
                required DateTime savedAt,
              }) => LiveSessionsCompanion.insert(
                id: id,
                payload: payload,
                savedAt: savedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LiveSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LiveSessionsTable,
      LiveSession,
      $$LiveSessionsTableFilterComposer,
      $$LiveSessionsTableOrderingComposer,
      $$LiveSessionsTableAnnotationComposer,
      $$LiveSessionsTableCreateCompanionBuilder,
      $$LiveSessionsTableUpdateCompanionBuilder,
      (
        LiveSession,
        BaseReferences<_$AppDatabase, $LiveSessionsTable, LiveSession>,
      ),
      LiveSession,
      PrefetchHooks Function()
    >;
typedef $$BarsTableCreateCompanionBuilder =
    BarsCompanion Function({
      Value<int> id,
      required String unit,
      required String name,
      Value<String?> seedKey,
      required double weightKg,
      Value<bool> isCustom,
    });
typedef $$BarsTableUpdateCompanionBuilder =
    BarsCompanion Function({
      Value<int> id,
      Value<String> unit,
      Value<String> name,
      Value<String?> seedKey,
      Value<double> weightKg,
      Value<bool> isCustom,
    });

class $$BarsTableFilterComposer extends Composer<_$AppDatabase, $BarsTable> {
  $$BarsTableFilterComposer({
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

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seedKey => $composableBuilder(
    column: $table.seedKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BarsTableOrderingComposer extends Composer<_$AppDatabase, $BarsTable> {
  $$BarsTableOrderingComposer({
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

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seedKey => $composableBuilder(
    column: $table.seedKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BarsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BarsTable> {
  $$BarsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get seedKey =>
      $composableBuilder(column: $table.seedKey, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);
}

class $$BarsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BarsTable,
          Bar,
          $$BarsTableFilterComposer,
          $$BarsTableOrderingComposer,
          $$BarsTableAnnotationComposer,
          $$BarsTableCreateCompanionBuilder,
          $$BarsTableUpdateCompanionBuilder,
          (Bar, BaseReferences<_$AppDatabase, $BarsTable, Bar>),
          Bar,
          PrefetchHooks Function()
        > {
  $$BarsTableTableManager(_$AppDatabase db, $BarsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BarsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BarsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BarsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> seedKey = const Value.absent(),
                Value<double> weightKg = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
              }) => BarsCompanion(
                id: id,
                unit: unit,
                name: name,
                seedKey: seedKey,
                weightKg: weightKg,
                isCustom: isCustom,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String unit,
                required String name,
                Value<String?> seedKey = const Value.absent(),
                required double weightKg,
                Value<bool> isCustom = const Value.absent(),
              }) => BarsCompanion.insert(
                id: id,
                unit: unit,
                name: name,
                seedKey: seedKey,
                weightKg: weightKg,
                isCustom: isCustom,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BarsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BarsTable,
      Bar,
      $$BarsTableFilterComposer,
      $$BarsTableOrderingComposer,
      $$BarsTableAnnotationComposer,
      $$BarsTableCreateCompanionBuilder,
      $$BarsTableUpdateCompanionBuilder,
      (Bar, BaseReferences<_$AppDatabase, $BarsTable, Bar>),
      Bar,
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
  $$CustomThemesTableTableManager get customThemes =>
      $$CustomThemesTableTableManager(_db, _db.customThemes);
  $$LiveSessionsTableTableManager get liveSessions =>
      $$LiveSessionsTableTableManager(_db, _db.liveSessions);
  $$BarsTableTableManager get bars => $$BarsTableTableManager(_db, _db.bars);
}
