// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SourcesTable extends Sources with TableInfo<$SourcesTable, SourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourcesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _siteUrlMeta = const VerificationMeta(
    'siteUrl',
  );
  @override
  late final GeneratedColumn<String> siteUrl = GeneratedColumn<String>(
    'site_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _feedUrlMeta = const VerificationMeta(
    'feedUrl',
  );
  @override
  late final GeneratedColumn<String> feedUrl = GeneratedColumn<String>(
    'feed_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accentDarkMeta = const VerificationMeta(
    'accentDark',
  );
  @override
  late final GeneratedColumn<int> accentDark = GeneratedColumn<int>(
    'accent_dark',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accentLightMeta = const VerificationMeta(
    'accentLight',
  );
  @override
  late final GeneratedColumn<int> accentLight = GeneratedColumn<int>(
    'accent_light',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SourceType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SourceType>($SourcesTable.$convertertype);
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mutedInLatestMeta = const VerificationMeta(
    'mutedInLatest',
  );
  @override
  late final GeneratedColumn<bool> mutedInLatest = GeneratedColumn<bool>(
    'muted_in_latest',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("muted_in_latest" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  @override
  late final GeneratedColumn<String> lastModified = GeneratedColumn<String>(
    'last_modified',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastFetchedAtMeta = const VerificationMeta(
    'lastFetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastFetchedAt =
      GeneratedColumn<DateTime>(
        'last_fetched_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _failingSinceMeta = const VerificationMeta(
    'failingSince',
  );
  @override
  late final GeneratedColumn<DateTime> failingSince = GeneratedColumn<DateTime>(
    'failing_since',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    siteUrl,
    feedUrl,
    category,
    accentDark,
    accentLight,
    type,
    enabled,
    sortOrder,
    mutedInLatest,
    etag,
    lastModified,
    lastFetchedAt,
    addedAt,
    failingSince,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('site_url')) {
      context.handle(
        _siteUrlMeta,
        siteUrl.isAcceptableOrUnknown(data['site_url']!, _siteUrlMeta),
      );
    }
    if (data.containsKey('feed_url')) {
      context.handle(
        _feedUrlMeta,
        feedUrl.isAcceptableOrUnknown(data['feed_url']!, _feedUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_feedUrlMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('accent_dark')) {
      context.handle(
        _accentDarkMeta,
        accentDark.isAcceptableOrUnknown(data['accent_dark']!, _accentDarkMeta),
      );
    } else if (isInserting) {
      context.missing(_accentDarkMeta);
    }
    if (data.containsKey('accent_light')) {
      context.handle(
        _accentLightMeta,
        accentLight.isAcceptableOrUnknown(
          data['accent_light']!,
          _accentLightMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_accentLightMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('muted_in_latest')) {
      context.handle(
        _mutedInLatestMeta,
        mutedInLatest.isAcceptableOrUnknown(
          data['muted_in_latest']!,
          _mutedInLatestMeta,
        ),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    }
    if (data.containsKey('last_fetched_at')) {
      context.handle(
        _lastFetchedAtMeta,
        lastFetchedAt.isAcceptableOrUnknown(
          data['last_fetched_at']!,
          _lastFetchedAtMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('failing_since')) {
      context.handle(
        _failingSinceMeta,
        failingSince.isAcceptableOrUnknown(
          data['failing_since']!,
          _failingSinceMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      siteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}site_url'],
      ),
      feedUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feed_url'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      accentDark: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accent_dark'],
      )!,
      accentLight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accent_light'],
      )!,
      type: $SourcesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      mutedInLatest: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}muted_in_latest'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified'],
      ),
      lastFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_fetched_at'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      failingSince: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}failing_since'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $SourcesTable createAlias(String alias) {
    return $SourcesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SourceType, String, String> $convertertype =
      const EnumNameConverter<SourceType>(SourceType.values);
}

class SourceRow extends DataClass implements Insertable<SourceRow> {
  final int id;
  final String title;
  final String? siteUrl;
  final String feedUrl;
  final String category;

  /// The two tones of the source accent — light-on-black and deep-on-paper.
  final int accentDark;
  final int accentLight;
  final SourceType type;
  final bool enabled;
  final int sortOrder;

  /// Kept out of the merged Latest list, while still appearing under its own
  /// category. For a firehose the reader wants, but not in with everything
  /// else.
  final bool mutedInLatest;

  /// Conditional-GET validators, so a refresh usually costs a 304.
  final String? etag;
  final String? lastModified;
  final DateTime? lastFetchedAt;
  final DateTime addedAt;

  /// A feed that stops responding is stated in words on its own screen, never
  /// as a badge. These two columns are what that screen reads.
  final DateTime? failingSince;
  final String? lastError;
  const SourceRow({
    required this.id,
    required this.title,
    this.siteUrl,
    required this.feedUrl,
    required this.category,
    required this.accentDark,
    required this.accentLight,
    required this.type,
    required this.enabled,
    required this.sortOrder,
    required this.mutedInLatest,
    this.etag,
    this.lastModified,
    this.lastFetchedAt,
    required this.addedAt,
    this.failingSince,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || siteUrl != null) {
      map['site_url'] = Variable<String>(siteUrl);
    }
    map['feed_url'] = Variable<String>(feedUrl);
    map['category'] = Variable<String>(category);
    map['accent_dark'] = Variable<int>(accentDark);
    map['accent_light'] = Variable<int>(accentLight);
    {
      map['type'] = Variable<String>($SourcesTable.$convertertype.toSql(type));
    }
    map['enabled'] = Variable<bool>(enabled);
    map['sort_order'] = Variable<int>(sortOrder);
    map['muted_in_latest'] = Variable<bool>(mutedInLatest);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || lastModified != null) {
      map['last_modified'] = Variable<String>(lastModified);
    }
    if (!nullToAbsent || lastFetchedAt != null) {
      map['last_fetched_at'] = Variable<DateTime>(lastFetchedAt);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || failingSince != null) {
      map['failing_since'] = Variable<DateTime>(failingSince);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SourcesCompanion toCompanion(bool nullToAbsent) {
    return SourcesCompanion(
      id: Value(id),
      title: Value(title),
      siteUrl: siteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(siteUrl),
      feedUrl: Value(feedUrl),
      category: Value(category),
      accentDark: Value(accentDark),
      accentLight: Value(accentLight),
      type: Value(type),
      enabled: Value(enabled),
      sortOrder: Value(sortOrder),
      mutedInLatest: Value(mutedInLatest),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      lastModified: lastModified == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModified),
      lastFetchedAt: lastFetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFetchedAt),
      addedAt: Value(addedAt),
      failingSince: failingSince == null && nullToAbsent
          ? const Value.absent()
          : Value(failingSince),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SourceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceRow(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      siteUrl: serializer.fromJson<String?>(json['siteUrl']),
      feedUrl: serializer.fromJson<String>(json['feedUrl']),
      category: serializer.fromJson<String>(json['category']),
      accentDark: serializer.fromJson<int>(json['accentDark']),
      accentLight: serializer.fromJson<int>(json['accentLight']),
      type: $SourcesTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      enabled: serializer.fromJson<bool>(json['enabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      mutedInLatest: serializer.fromJson<bool>(json['mutedInLatest']),
      etag: serializer.fromJson<String?>(json['etag']),
      lastModified: serializer.fromJson<String?>(json['lastModified']),
      lastFetchedAt: serializer.fromJson<DateTime?>(json['lastFetchedAt']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      failingSince: serializer.fromJson<DateTime?>(json['failingSince']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'siteUrl': serializer.toJson<String?>(siteUrl),
      'feedUrl': serializer.toJson<String>(feedUrl),
      'category': serializer.toJson<String>(category),
      'accentDark': serializer.toJson<int>(accentDark),
      'accentLight': serializer.toJson<int>(accentLight),
      'type': serializer.toJson<String>(
        $SourcesTable.$convertertype.toJson(type),
      ),
      'enabled': serializer.toJson<bool>(enabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'mutedInLatest': serializer.toJson<bool>(mutedInLatest),
      'etag': serializer.toJson<String?>(etag),
      'lastModified': serializer.toJson<String?>(lastModified),
      'lastFetchedAt': serializer.toJson<DateTime?>(lastFetchedAt),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'failingSince': serializer.toJson<DateTime?>(failingSince),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SourceRow copyWith({
    int? id,
    String? title,
    Value<String?> siteUrl = const Value.absent(),
    String? feedUrl,
    String? category,
    int? accentDark,
    int? accentLight,
    SourceType? type,
    bool? enabled,
    int? sortOrder,
    bool? mutedInLatest,
    Value<String?> etag = const Value.absent(),
    Value<String?> lastModified = const Value.absent(),
    Value<DateTime?> lastFetchedAt = const Value.absent(),
    DateTime? addedAt,
    Value<DateTime?> failingSince = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => SourceRow(
    id: id ?? this.id,
    title: title ?? this.title,
    siteUrl: siteUrl.present ? siteUrl.value : this.siteUrl,
    feedUrl: feedUrl ?? this.feedUrl,
    category: category ?? this.category,
    accentDark: accentDark ?? this.accentDark,
    accentLight: accentLight ?? this.accentLight,
    type: type ?? this.type,
    enabled: enabled ?? this.enabled,
    sortOrder: sortOrder ?? this.sortOrder,
    mutedInLatest: mutedInLatest ?? this.mutedInLatest,
    etag: etag.present ? etag.value : this.etag,
    lastModified: lastModified.present ? lastModified.value : this.lastModified,
    lastFetchedAt: lastFetchedAt.present
        ? lastFetchedAt.value
        : this.lastFetchedAt,
    addedAt: addedAt ?? this.addedAt,
    failingSince: failingSince.present ? failingSince.value : this.failingSince,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  SourceRow copyWithCompanion(SourcesCompanion data) {
    return SourceRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      siteUrl: data.siteUrl.present ? data.siteUrl.value : this.siteUrl,
      feedUrl: data.feedUrl.present ? data.feedUrl.value : this.feedUrl,
      category: data.category.present ? data.category.value : this.category,
      accentDark: data.accentDark.present
          ? data.accentDark.value
          : this.accentDark,
      accentLight: data.accentLight.present
          ? data.accentLight.value
          : this.accentLight,
      type: data.type.present ? data.type.value : this.type,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      mutedInLatest: data.mutedInLatest.present
          ? data.mutedInLatest.value
          : this.mutedInLatest,
      etag: data.etag.present ? data.etag.value : this.etag,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      lastFetchedAt: data.lastFetchedAt.present
          ? data.lastFetchedAt.value
          : this.lastFetchedAt,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      failingSince: data.failingSince.present
          ? data.failingSince.value
          : this.failingSince,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('siteUrl: $siteUrl, ')
          ..write('feedUrl: $feedUrl, ')
          ..write('category: $category, ')
          ..write('accentDark: $accentDark, ')
          ..write('accentLight: $accentLight, ')
          ..write('type: $type, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('mutedInLatest: $mutedInLatest, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified, ')
          ..write('lastFetchedAt: $lastFetchedAt, ')
          ..write('addedAt: $addedAt, ')
          ..write('failingSince: $failingSince, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    siteUrl,
    feedUrl,
    category,
    accentDark,
    accentLight,
    type,
    enabled,
    sortOrder,
    mutedInLatest,
    etag,
    lastModified,
    lastFetchedAt,
    addedAt,
    failingSince,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.siteUrl == this.siteUrl &&
          other.feedUrl == this.feedUrl &&
          other.category == this.category &&
          other.accentDark == this.accentDark &&
          other.accentLight == this.accentLight &&
          other.type == this.type &&
          other.enabled == this.enabled &&
          other.sortOrder == this.sortOrder &&
          other.mutedInLatest == this.mutedInLatest &&
          other.etag == this.etag &&
          other.lastModified == this.lastModified &&
          other.lastFetchedAt == this.lastFetchedAt &&
          other.addedAt == this.addedAt &&
          other.failingSince == this.failingSince &&
          other.lastError == this.lastError);
}

class SourcesCompanion extends UpdateCompanion<SourceRow> {
  final Value<int> id;
  final Value<String> title;
  final Value<String?> siteUrl;
  final Value<String> feedUrl;
  final Value<String> category;
  final Value<int> accentDark;
  final Value<int> accentLight;
  final Value<SourceType> type;
  final Value<bool> enabled;
  final Value<int> sortOrder;
  final Value<bool> mutedInLatest;
  final Value<String?> etag;
  final Value<String?> lastModified;
  final Value<DateTime?> lastFetchedAt;
  final Value<DateTime> addedAt;
  final Value<DateTime?> failingSince;
  final Value<String?> lastError;
  const SourcesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.siteUrl = const Value.absent(),
    this.feedUrl = const Value.absent(),
    this.category = const Value.absent(),
    this.accentDark = const Value.absent(),
    this.accentLight = const Value.absent(),
    this.type = const Value.absent(),
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.mutedInLatest = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.lastFetchedAt = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.failingSince = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  SourcesCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.siteUrl = const Value.absent(),
    required String feedUrl,
    required String category,
    required int accentDark,
    required int accentLight,
    required SourceType type,
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.mutedInLatest = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.lastFetchedAt = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.failingSince = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : title = Value(title),
       feedUrl = Value(feedUrl),
       category = Value(category),
       accentDark = Value(accentDark),
       accentLight = Value(accentLight),
       type = Value(type);
  static Insertable<SourceRow> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? siteUrl,
    Expression<String>? feedUrl,
    Expression<String>? category,
    Expression<int>? accentDark,
    Expression<int>? accentLight,
    Expression<String>? type,
    Expression<bool>? enabled,
    Expression<int>? sortOrder,
    Expression<bool>? mutedInLatest,
    Expression<String>? etag,
    Expression<String>? lastModified,
    Expression<DateTime>? lastFetchedAt,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? failingSince,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (siteUrl != null) 'site_url': siteUrl,
      if (feedUrl != null) 'feed_url': feedUrl,
      if (category != null) 'category': category,
      if (accentDark != null) 'accent_dark': accentDark,
      if (accentLight != null) 'accent_light': accentLight,
      if (type != null) 'type': type,
      if (enabled != null) 'enabled': enabled,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (mutedInLatest != null) 'muted_in_latest': mutedInLatest,
      if (etag != null) 'etag': etag,
      if (lastModified != null) 'last_modified': lastModified,
      if (lastFetchedAt != null) 'last_fetched_at': lastFetchedAt,
      if (addedAt != null) 'added_at': addedAt,
      if (failingSince != null) 'failing_since': failingSince,
      if (lastError != null) 'last_error': lastError,
    });
  }

  SourcesCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String?>? siteUrl,
    Value<String>? feedUrl,
    Value<String>? category,
    Value<int>? accentDark,
    Value<int>? accentLight,
    Value<SourceType>? type,
    Value<bool>? enabled,
    Value<int>? sortOrder,
    Value<bool>? mutedInLatest,
    Value<String?>? etag,
    Value<String?>? lastModified,
    Value<DateTime?>? lastFetchedAt,
    Value<DateTime>? addedAt,
    Value<DateTime?>? failingSince,
    Value<String?>? lastError,
  }) {
    return SourcesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      siteUrl: siteUrl ?? this.siteUrl,
      feedUrl: feedUrl ?? this.feedUrl,
      category: category ?? this.category,
      accentDark: accentDark ?? this.accentDark,
      accentLight: accentLight ?? this.accentLight,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      mutedInLatest: mutedInLatest ?? this.mutedInLatest,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      addedAt: addedAt ?? this.addedAt,
      failingSince: failingSince ?? this.failingSince,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (siteUrl.present) {
      map['site_url'] = Variable<String>(siteUrl.value);
    }
    if (feedUrl.present) {
      map['feed_url'] = Variable<String>(feedUrl.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (accentDark.present) {
      map['accent_dark'] = Variable<int>(accentDark.value);
    }
    if (accentLight.present) {
      map['accent_light'] = Variable<int>(accentLight.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $SourcesTable.$convertertype.toSql(type.value),
      );
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (mutedInLatest.present) {
      map['muted_in_latest'] = Variable<bool>(mutedInLatest.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<String>(lastModified.value);
    }
    if (lastFetchedAt.present) {
      map['last_fetched_at'] = Variable<DateTime>(lastFetchedAt.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (failingSince.present) {
      map['failing_since'] = Variable<DateTime>(failingSince.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourcesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('siteUrl: $siteUrl, ')
          ..write('feedUrl: $feedUrl, ')
          ..write('category: $category, ')
          ..write('accentDark: $accentDark, ')
          ..write('accentLight: $accentLight, ')
          ..write('type: $type, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('mutedInLatest: $mutedInLatest, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified, ')
          ..write('lastFetchedAt: $lastFetchedAt, ')
          ..write('addedAt: $addedAt, ')
          ..write('failingSince: $failingSince, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $ArticlesTable extends Articles
    with TableInfo<$ArticlesTable, ArticleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArticlesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _guidMeta = const VerificationMeta('guid');
  @override
  late final GeneratedColumn<String> guid = GeneratedColumn<String>(
    'guid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentSnippetMeta = const VerificationMeta(
    'contentSnippet',
  );
  @override
  late final GeneratedColumn<String> contentSnippet = GeneratedColumn<String>(
    'content_snippet',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fullContentHtmlMeta = const VerificationMeta(
    'fullContentHtml',
  );
  @override
  late final GeneratedColumn<String> fullContentHtml = GeneratedColumn<String>(
    'full_content_html',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkMeta = const VerificationMeta('link');
  @override
  late final GeneratedColumn<String> link = GeneratedColumn<String>(
    'link',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canonicalUrlMeta = const VerificationMeta(
    'canonicalUrl',
  );
  @override
  late final GeneratedColumn<String> canonicalUrl = GeneratedColumn<String>(
    'canonical_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _titleKeyMeta = const VerificationMeta(
    'titleKey',
  );
  @override
  late final GeneratedColumn<String> titleKey = GeneratedColumn<String>(
    'title_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _seenInLingerMeta = const VerificationMeta(
    'seenInLinger',
  );
  @override
  late final GeneratedColumn<bool> seenInLinger = GeneratedColumn<bool>(
    'seen_in_linger',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("seen_in_linger" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _readFullMeta = const VerificationMeta(
    'readFull',
  );
  @override
  late final GeneratedColumn<bool> readFull = GeneratedColumn<bool>(
    'read_full',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("read_full" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    guid,
    title,
    summary,
    contentSnippet,
    fullContentHtml,
    link,
    canonicalUrl,
    titleKey,
    author,
    publishedAt,
    imageUrl,
    fetchedAt,
    seenInLinger,
    readFull,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'articles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArticleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('guid')) {
      context.handle(
        _guidMeta,
        guid.isAcceptableOrUnknown(data['guid']!, _guidMeta),
      );
    } else if (isInserting) {
      context.missing(_guidMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('content_snippet')) {
      context.handle(
        _contentSnippetMeta,
        contentSnippet.isAcceptableOrUnknown(
          data['content_snippet']!,
          _contentSnippetMeta,
        ),
      );
    }
    if (data.containsKey('full_content_html')) {
      context.handle(
        _fullContentHtmlMeta,
        fullContentHtml.isAcceptableOrUnknown(
          data['full_content_html']!,
          _fullContentHtmlMeta,
        ),
      );
    }
    if (data.containsKey('link')) {
      context.handle(
        _linkMeta,
        link.isAcceptableOrUnknown(data['link']!, _linkMeta),
      );
    } else if (isInserting) {
      context.missing(_linkMeta);
    }
    if (data.containsKey('canonical_url')) {
      context.handle(
        _canonicalUrlMeta,
        canonicalUrl.isAcceptableOrUnknown(
          data['canonical_url']!,
          _canonicalUrlMeta,
        ),
      );
    }
    if (data.containsKey('title_key')) {
      context.handle(
        _titleKeyMeta,
        titleKey.isAcceptableOrUnknown(data['title_key']!, _titleKeyMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishedAtMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    }
    if (data.containsKey('seen_in_linger')) {
      context.handle(
        _seenInLingerMeta,
        seenInLinger.isAcceptableOrUnknown(
          data['seen_in_linger']!,
          _seenInLingerMeta,
        ),
      );
    }
    if (data.containsKey('read_full')) {
      context.handle(
        _readFullMeta,
        readFull.isAcceptableOrUnknown(data['read_full']!, _readFullMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceId, guid},
  ];
  @override
  ArticleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArticleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      guid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guid'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      contentSnippet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_snippet'],
      ),
      fullContentHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_content_html'],
      ),
      link: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link'],
      )!,
      canonicalUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_url'],
      )!,
      titleKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_key'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
      seenInLinger: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}seen_in_linger'],
      )!,
      readFull: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}read_full'],
      )!,
    );
  }

  @override
  $ArticlesTable createAlias(String alias) {
    return $ArticlesTable(attachedDatabase, alias);
  }
}

class ArticleRow extends DataClass implements Insertable<ArticleRow> {
  final int id;
  final int sourceId;

  /// Feed-provided identity, falling back to the link when absent.
  final String guid;
  final String title;
  final String? summary;
  final String? contentSnippet;

  /// Populated only when a full-content feed or on-device extraction provides
  /// it. Null means the Reader must extract, or degrade to the publisher.
  final String? fullContentHtml;
  final String link;

  /// The link reduced to the story's identity — tracking parameters stripped,
  /// aggregator redirects unwrapped. Two feeds carrying the same article agree
  /// on this, which is what makes cross-feed dedup and shared read state work.
  final String canonicalUrl;

  /// A loose fingerprint of the headline, for the same story filed under two
  /// slightly different titles. Empty when the title is too short to be sure.
  final String titleKey;
  final String? author;
  final DateTime publishedAt;
  final String? imageUrl;
  final DateTime fetchedAt;

  /// The card settled as the active card in Linger. Set there and nowhere
  /// else: it keeps an item from coming back round in Linger, and has no
  /// effect on Today at all.
  final bool seenInLinger;

  /// The reader opened the full article, from Today or from Linger. The only
  /// thing that counts as having read something.
  final bool readFull;
  const ArticleRow({
    required this.id,
    required this.sourceId,
    required this.guid,
    required this.title,
    this.summary,
    this.contentSnippet,
    this.fullContentHtml,
    required this.link,
    required this.canonicalUrl,
    required this.titleKey,
    this.author,
    required this.publishedAt,
    this.imageUrl,
    required this.fetchedAt,
    required this.seenInLinger,
    required this.readFull,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<int>(sourceId);
    map['guid'] = Variable<String>(guid);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || contentSnippet != null) {
      map['content_snippet'] = Variable<String>(contentSnippet);
    }
    if (!nullToAbsent || fullContentHtml != null) {
      map['full_content_html'] = Variable<String>(fullContentHtml);
    }
    map['link'] = Variable<String>(link);
    map['canonical_url'] = Variable<String>(canonicalUrl);
    map['title_key'] = Variable<String>(titleKey);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    map['published_at'] = Variable<DateTime>(publishedAt);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    map['seen_in_linger'] = Variable<bool>(seenInLinger);
    map['read_full'] = Variable<bool>(readFull);
    return map;
  }

  ArticlesCompanion toCompanion(bool nullToAbsent) {
    return ArticlesCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      guid: Value(guid),
      title: Value(title),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      contentSnippet: contentSnippet == null && nullToAbsent
          ? const Value.absent()
          : Value(contentSnippet),
      fullContentHtml: fullContentHtml == null && nullToAbsent
          ? const Value.absent()
          : Value(fullContentHtml),
      link: Value(link),
      canonicalUrl: Value(canonicalUrl),
      titleKey: Value(titleKey),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      publishedAt: Value(publishedAt),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      fetchedAt: Value(fetchedAt),
      seenInLinger: Value(seenInLinger),
      readFull: Value(readFull),
    );
  }

  factory ArticleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArticleRow(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<int>(json['sourceId']),
      guid: serializer.fromJson<String>(json['guid']),
      title: serializer.fromJson<String>(json['title']),
      summary: serializer.fromJson<String?>(json['summary']),
      contentSnippet: serializer.fromJson<String?>(json['contentSnippet']),
      fullContentHtml: serializer.fromJson<String?>(json['fullContentHtml']),
      link: serializer.fromJson<String>(json['link']),
      canonicalUrl: serializer.fromJson<String>(json['canonicalUrl']),
      titleKey: serializer.fromJson<String>(json['titleKey']),
      author: serializer.fromJson<String?>(json['author']),
      publishedAt: serializer.fromJson<DateTime>(json['publishedAt']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      seenInLinger: serializer.fromJson<bool>(json['seenInLinger']),
      readFull: serializer.fromJson<bool>(json['readFull']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceId': serializer.toJson<int>(sourceId),
      'guid': serializer.toJson<String>(guid),
      'title': serializer.toJson<String>(title),
      'summary': serializer.toJson<String?>(summary),
      'contentSnippet': serializer.toJson<String?>(contentSnippet),
      'fullContentHtml': serializer.toJson<String?>(fullContentHtml),
      'link': serializer.toJson<String>(link),
      'canonicalUrl': serializer.toJson<String>(canonicalUrl),
      'titleKey': serializer.toJson<String>(titleKey),
      'author': serializer.toJson<String?>(author),
      'publishedAt': serializer.toJson<DateTime>(publishedAt),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'seenInLinger': serializer.toJson<bool>(seenInLinger),
      'readFull': serializer.toJson<bool>(readFull),
    };
  }

  ArticleRow copyWith({
    int? id,
    int? sourceId,
    String? guid,
    String? title,
    Value<String?> summary = const Value.absent(),
    Value<String?> contentSnippet = const Value.absent(),
    Value<String?> fullContentHtml = const Value.absent(),
    String? link,
    String? canonicalUrl,
    String? titleKey,
    Value<String?> author = const Value.absent(),
    DateTime? publishedAt,
    Value<String?> imageUrl = const Value.absent(),
    DateTime? fetchedAt,
    bool? seenInLinger,
    bool? readFull,
  }) => ArticleRow(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    guid: guid ?? this.guid,
    title: title ?? this.title,
    summary: summary.present ? summary.value : this.summary,
    contentSnippet: contentSnippet.present
        ? contentSnippet.value
        : this.contentSnippet,
    fullContentHtml: fullContentHtml.present
        ? fullContentHtml.value
        : this.fullContentHtml,
    link: link ?? this.link,
    canonicalUrl: canonicalUrl ?? this.canonicalUrl,
    titleKey: titleKey ?? this.titleKey,
    author: author.present ? author.value : this.author,
    publishedAt: publishedAt ?? this.publishedAt,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    seenInLinger: seenInLinger ?? this.seenInLinger,
    readFull: readFull ?? this.readFull,
  );
  ArticleRow copyWithCompanion(ArticlesCompanion data) {
    return ArticleRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      guid: data.guid.present ? data.guid.value : this.guid,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      contentSnippet: data.contentSnippet.present
          ? data.contentSnippet.value
          : this.contentSnippet,
      fullContentHtml: data.fullContentHtml.present
          ? data.fullContentHtml.value
          : this.fullContentHtml,
      link: data.link.present ? data.link.value : this.link,
      canonicalUrl: data.canonicalUrl.present
          ? data.canonicalUrl.value
          : this.canonicalUrl,
      titleKey: data.titleKey.present ? data.titleKey.value : this.titleKey,
      author: data.author.present ? data.author.value : this.author,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      seenInLinger: data.seenInLinger.present
          ? data.seenInLinger.value
          : this.seenInLinger,
      readFull: data.readFull.present ? data.readFull.value : this.readFull,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArticleRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('guid: $guid, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('contentSnippet: $contentSnippet, ')
          ..write('fullContentHtml: $fullContentHtml, ')
          ..write('link: $link, ')
          ..write('canonicalUrl: $canonicalUrl, ')
          ..write('titleKey: $titleKey, ')
          ..write('author: $author, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('seenInLinger: $seenInLinger, ')
          ..write('readFull: $readFull')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    guid,
    title,
    summary,
    contentSnippet,
    fullContentHtml,
    link,
    canonicalUrl,
    titleKey,
    author,
    publishedAt,
    imageUrl,
    fetchedAt,
    seenInLinger,
    readFull,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArticleRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.guid == this.guid &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.contentSnippet == this.contentSnippet &&
          other.fullContentHtml == this.fullContentHtml &&
          other.link == this.link &&
          other.canonicalUrl == this.canonicalUrl &&
          other.titleKey == this.titleKey &&
          other.author == this.author &&
          other.publishedAt == this.publishedAt &&
          other.imageUrl == this.imageUrl &&
          other.fetchedAt == this.fetchedAt &&
          other.seenInLinger == this.seenInLinger &&
          other.readFull == this.readFull);
}

class ArticlesCompanion extends UpdateCompanion<ArticleRow> {
  final Value<int> id;
  final Value<int> sourceId;
  final Value<String> guid;
  final Value<String> title;
  final Value<String?> summary;
  final Value<String?> contentSnippet;
  final Value<String?> fullContentHtml;
  final Value<String> link;
  final Value<String> canonicalUrl;
  final Value<String> titleKey;
  final Value<String?> author;
  final Value<DateTime> publishedAt;
  final Value<String?> imageUrl;
  final Value<DateTime> fetchedAt;
  final Value<bool> seenInLinger;
  final Value<bool> readFull;
  const ArticlesCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.guid = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.contentSnippet = const Value.absent(),
    this.fullContentHtml = const Value.absent(),
    this.link = const Value.absent(),
    this.canonicalUrl = const Value.absent(),
    this.titleKey = const Value.absent(),
    this.author = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.seenInLinger = const Value.absent(),
    this.readFull = const Value.absent(),
  });
  ArticlesCompanion.insert({
    this.id = const Value.absent(),
    required int sourceId,
    required String guid,
    required String title,
    this.summary = const Value.absent(),
    this.contentSnippet = const Value.absent(),
    this.fullContentHtml = const Value.absent(),
    required String link,
    this.canonicalUrl = const Value.absent(),
    this.titleKey = const Value.absent(),
    this.author = const Value.absent(),
    required DateTime publishedAt,
    this.imageUrl = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.seenInLinger = const Value.absent(),
    this.readFull = const Value.absent(),
  }) : sourceId = Value(sourceId),
       guid = Value(guid),
       title = Value(title),
       link = Value(link),
       publishedAt = Value(publishedAt);
  static Insertable<ArticleRow> custom({
    Expression<int>? id,
    Expression<int>? sourceId,
    Expression<String>? guid,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? contentSnippet,
    Expression<String>? fullContentHtml,
    Expression<String>? link,
    Expression<String>? canonicalUrl,
    Expression<String>? titleKey,
    Expression<String>? author,
    Expression<DateTime>? publishedAt,
    Expression<String>? imageUrl,
    Expression<DateTime>? fetchedAt,
    Expression<bool>? seenInLinger,
    Expression<bool>? readFull,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (guid != null) 'guid': guid,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (contentSnippet != null) 'content_snippet': contentSnippet,
      if (fullContentHtml != null) 'full_content_html': fullContentHtml,
      if (link != null) 'link': link,
      if (canonicalUrl != null) 'canonical_url': canonicalUrl,
      if (titleKey != null) 'title_key': titleKey,
      if (author != null) 'author': author,
      if (publishedAt != null) 'published_at': publishedAt,
      if (imageUrl != null) 'image_url': imageUrl,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (seenInLinger != null) 'seen_in_linger': seenInLinger,
      if (readFull != null) 'read_full': readFull,
    });
  }

  ArticlesCompanion copyWith({
    Value<int>? id,
    Value<int>? sourceId,
    Value<String>? guid,
    Value<String>? title,
    Value<String?>? summary,
    Value<String?>? contentSnippet,
    Value<String?>? fullContentHtml,
    Value<String>? link,
    Value<String>? canonicalUrl,
    Value<String>? titleKey,
    Value<String?>? author,
    Value<DateTime>? publishedAt,
    Value<String?>? imageUrl,
    Value<DateTime>? fetchedAt,
    Value<bool>? seenInLinger,
    Value<bool>? readFull,
  }) {
    return ArticlesCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      guid: guid ?? this.guid,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      contentSnippet: contentSnippet ?? this.contentSnippet,
      fullContentHtml: fullContentHtml ?? this.fullContentHtml,
      link: link ?? this.link,
      canonicalUrl: canonicalUrl ?? this.canonicalUrl,
      titleKey: titleKey ?? this.titleKey,
      author: author ?? this.author,
      publishedAt: publishedAt ?? this.publishedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      seenInLinger: seenInLinger ?? this.seenInLinger,
      readFull: readFull ?? this.readFull,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (guid.present) {
      map['guid'] = Variable<String>(guid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (contentSnippet.present) {
      map['content_snippet'] = Variable<String>(contentSnippet.value);
    }
    if (fullContentHtml.present) {
      map['full_content_html'] = Variable<String>(fullContentHtml.value);
    }
    if (link.present) {
      map['link'] = Variable<String>(link.value);
    }
    if (canonicalUrl.present) {
      map['canonical_url'] = Variable<String>(canonicalUrl.value);
    }
    if (titleKey.present) {
      map['title_key'] = Variable<String>(titleKey.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (seenInLinger.present) {
      map['seen_in_linger'] = Variable<bool>(seenInLinger.value);
    }
    if (readFull.present) {
      map['read_full'] = Variable<bool>(readFull.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticlesCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('guid: $guid, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('contentSnippet: $contentSnippet, ')
          ..write('fullContentHtml: $fullContentHtml, ')
          ..write('link: $link, ')
          ..write('canonicalUrl: $canonicalUrl, ')
          ..write('titleKey: $titleKey, ')
          ..write('author: $author, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('seenInLinger: $seenInLinger, ')
          ..write('readFull: $readFull')
          ..write(')'))
        .toString();
  }
}

class $ReadEventsTable extends ReadEvents
    with TableInfo<$ReadEventsTable, ReadEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadEventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _articleIdMeta = const VerificationMeta(
    'articleId',
  );
  @override
  late final GeneratedColumn<int> articleId = GeneratedColumn<int>(
    'article_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES articles (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReadMode, String> mode =
      GeneratedColumn<String>(
        'mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ReadMode>($ReadEventsTable.$convertermode);
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _dwellMsMeta = const VerificationMeta(
    'dwellMs',
  );
  @override
  late final GeneratedColumn<int> dwellMs = GeneratedColumn<int>(
    'dwell_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, articleId, mode, at, dwellMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'read_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('article_id')) {
      context.handle(
        _articleIdMeta,
        articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    }
    if (data.containsKey('dwell_ms')) {
      context.handle(
        _dwellMsMeta,
        dwellMs.isAcceptableOrUnknown(data['dwell_ms']!, _dwellMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      articleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}article_id'],
      )!,
      mode: $ReadEventsTable.$convertermode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}mode'],
        )!,
      ),
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      dwellMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dwell_ms'],
      )!,
    );
  }

  @override
  $ReadEventsTable createAlias(String alias) {
    return $ReadEventsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ReadMode, String, String> $convertermode =
      const EnumNameConverter<ReadMode>(ReadMode.values);
}

class ReadEventRow extends DataClass implements Insertable<ReadEventRow> {
  final int id;
  final int articleId;
  final ReadMode mode;
  final DateTime at;
  final int dwellMs;
  const ReadEventRow({
    required this.id,
    required this.articleId,
    required this.mode,
    required this.at,
    required this.dwellMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['article_id'] = Variable<int>(articleId);
    {
      map['mode'] = Variable<String>(
        $ReadEventsTable.$convertermode.toSql(mode),
      );
    }
    map['at'] = Variable<DateTime>(at);
    map['dwell_ms'] = Variable<int>(dwellMs);
    return map;
  }

  ReadEventsCompanion toCompanion(bool nullToAbsent) {
    return ReadEventsCompanion(
      id: Value(id),
      articleId: Value(articleId),
      mode: Value(mode),
      at: Value(at),
      dwellMs: Value(dwellMs),
    );
  }

  factory ReadEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadEventRow(
      id: serializer.fromJson<int>(json['id']),
      articleId: serializer.fromJson<int>(json['articleId']),
      mode: $ReadEventsTable.$convertermode.fromJson(
        serializer.fromJson<String>(json['mode']),
      ),
      at: serializer.fromJson<DateTime>(json['at']),
      dwellMs: serializer.fromJson<int>(json['dwellMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'articleId': serializer.toJson<int>(articleId),
      'mode': serializer.toJson<String>(
        $ReadEventsTable.$convertermode.toJson(mode),
      ),
      'at': serializer.toJson<DateTime>(at),
      'dwellMs': serializer.toJson<int>(dwellMs),
    };
  }

  ReadEventRow copyWith({
    int? id,
    int? articleId,
    ReadMode? mode,
    DateTime? at,
    int? dwellMs,
  }) => ReadEventRow(
    id: id ?? this.id,
    articleId: articleId ?? this.articleId,
    mode: mode ?? this.mode,
    at: at ?? this.at,
    dwellMs: dwellMs ?? this.dwellMs,
  );
  ReadEventRow copyWithCompanion(ReadEventsCompanion data) {
    return ReadEventRow(
      id: data.id.present ? data.id.value : this.id,
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      mode: data.mode.present ? data.mode.value : this.mode,
      at: data.at.present ? data.at.value : this.at,
      dwellMs: data.dwellMs.present ? data.dwellMs.value : this.dwellMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadEventRow(')
          ..write('id: $id, ')
          ..write('articleId: $articleId, ')
          ..write('mode: $mode, ')
          ..write('at: $at, ')
          ..write('dwellMs: $dwellMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, articleId, mode, at, dwellMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadEventRow &&
          other.id == this.id &&
          other.articleId == this.articleId &&
          other.mode == this.mode &&
          other.at == this.at &&
          other.dwellMs == this.dwellMs);
}

class ReadEventsCompanion extends UpdateCompanion<ReadEventRow> {
  final Value<int> id;
  final Value<int> articleId;
  final Value<ReadMode> mode;
  final Value<DateTime> at;
  final Value<int> dwellMs;
  const ReadEventsCompanion({
    this.id = const Value.absent(),
    this.articleId = const Value.absent(),
    this.mode = const Value.absent(),
    this.at = const Value.absent(),
    this.dwellMs = const Value.absent(),
  });
  ReadEventsCompanion.insert({
    this.id = const Value.absent(),
    required int articleId,
    required ReadMode mode,
    this.at = const Value.absent(),
    this.dwellMs = const Value.absent(),
  }) : articleId = Value(articleId),
       mode = Value(mode);
  static Insertable<ReadEventRow> custom({
    Expression<int>? id,
    Expression<int>? articleId,
    Expression<String>? mode,
    Expression<DateTime>? at,
    Expression<int>? dwellMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (articleId != null) 'article_id': articleId,
      if (mode != null) 'mode': mode,
      if (at != null) 'at': at,
      if (dwellMs != null) 'dwell_ms': dwellMs,
    });
  }

  ReadEventsCompanion copyWith({
    Value<int>? id,
    Value<int>? articleId,
    Value<ReadMode>? mode,
    Value<DateTime>? at,
    Value<int>? dwellMs,
  }) {
    return ReadEventsCompanion(
      id: id ?? this.id,
      articleId: articleId ?? this.articleId,
      mode: mode ?? this.mode,
      at: at ?? this.at,
      dwellMs: dwellMs ?? this.dwellMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (articleId.present) {
      map['article_id'] = Variable<int>(articleId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(
        $ReadEventsTable.$convertermode.toSql(mode.value),
      );
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (dwellMs.present) {
      map['dwell_ms'] = Variable<int>(dwellMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadEventsCompanion(')
          ..write('id: $id, ')
          ..write('articleId: $articleId, ')
          ..write('mode: $mode, ')
          ..write('at: $at, ')
          ..write('dwellMs: $dwellMs')
          ..write(')'))
        .toString();
  }
}

class $CaughtUpDaysTable extends CaughtUpDays
    with TableInfo<$CaughtUpDaysTable, CaughtUpRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaughtUpDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<DateTime> day = GeneratedColumn<DateTime>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [day];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'caught_up_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<CaughtUpRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  CaughtUpRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaughtUpRow(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}day'],
      )!,
    );
  }

  @override
  $CaughtUpDaysTable createAlias(String alias) {
    return $CaughtUpDaysTable(attachedDatabase, alias);
  }
}

class CaughtUpRow extends DataClass implements Insertable<CaughtUpRow> {
  final DateTime day;
  const CaughtUpRow({required this.day});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<DateTime>(day);
    return map;
  }

  CaughtUpDaysCompanion toCompanion(bool nullToAbsent) {
    return CaughtUpDaysCompanion(day: Value(day));
  }

  factory CaughtUpRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaughtUpRow(day: serializer.fromJson<DateTime>(json['day']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'day': serializer.toJson<DateTime>(day)};
  }

  CaughtUpRow copyWith({DateTime? day}) => CaughtUpRow(day: day ?? this.day);
  CaughtUpRow copyWithCompanion(CaughtUpDaysCompanion data) {
    return CaughtUpRow(day: data.day.present ? data.day.value : this.day);
  }

  @override
  String toString() {
    return (StringBuffer('CaughtUpRow(')
          ..write('day: $day')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => day.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CaughtUpRow && other.day == this.day);
}

class CaughtUpDaysCompanion extends UpdateCompanion<CaughtUpRow> {
  final Value<DateTime> day;
  final Value<int> rowid;
  const CaughtUpDaysCompanion({
    this.day = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaughtUpDaysCompanion.insert({
    required DateTime day,
    this.rowid = const Value.absent(),
  }) : day = Value(day);
  static Insertable<CaughtUpRow> custom({
    Expression<DateTime>? day,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaughtUpDaysCompanion copyWith({Value<DateTime>? day, Value<int>? rowid}) {
    return CaughtUpDaysCompanion(
      day: day ?? this.day,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<DateTime>(day.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaughtUpDaysCompanion(')
          ..write('day: $day, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$HsDatabase extends GeneratedDatabase {
  _$HsDatabase(QueryExecutor e) : super(e);
  $HsDatabaseManager get managers => $HsDatabaseManager(this);
  late final $SourcesTable sources = $SourcesTable(this);
  late final $ArticlesTable articles = $ArticlesTable(this);
  late final $ReadEventsTable readEvents = $ReadEventsTable(this);
  late final $CaughtUpDaysTable caughtUpDays = $CaughtUpDaysTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sources,
    articles,
    readEvents,
    caughtUpDays,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('articles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'articles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('read_events', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SourcesTableCreateCompanionBuilder = SourcesCompanion Function({
  Value<int> id,
  required String title,
  Value<String?> siteUrl,
  required String feedUrl,
  required String category,
  required int accentDark,
  required int accentLight,
  required SourceType type,
  Value<bool> enabled,
  Value<int> sortOrder,
  Value<bool> mutedInLatest,
  Value<String?> etag,
  Value<String?> lastModified,
  Value<DateTime?> lastFetchedAt,
  Value<DateTime> addedAt,
  Value<DateTime?> failingSince,
  Value<String?> lastError,
});
typedef $$SourcesTableUpdateCompanionBuilder = SourcesCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String?> siteUrl,
  Value<String> feedUrl,
  Value<String> category,
  Value<int> accentDark,
  Value<int> accentLight,
  Value<SourceType> type,
  Value<bool> enabled,
  Value<int> sortOrder,
  Value<bool> mutedInLatest,
  Value<String?> etag,
  Value<String?> lastModified,
  Value<DateTime?> lastFetchedAt,
  Value<DateTime> addedAt,
  Value<DateTime?> failingSince,
  Value<String?> lastError,
});

final class $$SourcesTableReferences
    extends BaseReferences<_$HsDatabase, $SourcesTable, SourceRow> {
  $$SourcesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ArticlesTable, List<ArticleRow>>
  _articlesRefsTable(_$HsDatabase db) => MultiTypedResultKey.fromTable(
    db.articles,
    aliasName: 'sources__id__articles__source_id',
  );

  $$ArticlesTableProcessedTableManager get articlesRefs {
    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_articlesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SourcesTableFilterComposer
    extends Composer<_$HsDatabase, $SourcesTable> {
  $$SourcesTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get siteUrl => $composableBuilder(
    column: $table.siteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feedUrl => $composableBuilder(
    column: $table.feedUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accentDark => $composableBuilder(
    column: $table.accentDark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accentLight => $composableBuilder(
    column: $table.accentLight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SourceType, SourceType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get mutedInLatest => $composableBuilder(
    column: $table.mutedInLatest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastFetchedAt => $composableBuilder(
    column: $table.lastFetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get failingSince => $composableBuilder(
    column: $table.failingSince,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> articlesRefs(
    Expression<bool> Function($$ArticlesTableFilterComposer f) f,
  ) {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourcesTableOrderingComposer
    extends Composer<_$HsDatabase, $SourcesTable> {
  $$SourcesTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get siteUrl => $composableBuilder(
    column: $table.siteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feedUrl => $composableBuilder(
    column: $table.feedUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accentDark => $composableBuilder(
    column: $table.accentDark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accentLight => $composableBuilder(
    column: $table.accentLight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get mutedInLatest => $composableBuilder(
    column: $table.mutedInLatest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastFetchedAt => $composableBuilder(
    column: $table.lastFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get failingSince => $composableBuilder(
    column: $table.failingSince,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SourcesTableAnnotationComposer
    extends Composer<_$HsDatabase, $SourcesTable> {
  $$SourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get siteUrl =>
      $composableBuilder(column: $table.siteUrl, builder: (column) => column);

  GeneratedColumn<String> get feedUrl =>
      $composableBuilder(column: $table.feedUrl, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get accentDark => $composableBuilder(
    column: $table.accentDark,
    builder: (column) => column,
  );

  GeneratedColumn<int> get accentLight => $composableBuilder(
    column: $table.accentLight,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SourceType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get mutedInLatest => $composableBuilder(
    column: $table.mutedInLatest,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastFetchedAt => $composableBuilder(
    column: $table.lastFetchedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get failingSince => $composableBuilder(
    column: $table.failingSince,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  Expression<T> articlesRefs<T extends Object>(
    Expression<T> Function($$ArticlesTableAnnotationComposer a) f,
  ) {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourcesTableTableManager
    extends
        RootTableManager<
          _$HsDatabase,
          $SourcesTable,
          SourceRow,
          $$SourcesTableFilterComposer,
          $$SourcesTableOrderingComposer,
          $$SourcesTableAnnotationComposer,
          $$SourcesTableCreateCompanionBuilder,
          $$SourcesTableUpdateCompanionBuilder,
          (SourceRow, $$SourcesTableReferences),
          SourceRow,
          PrefetchHooks Function({bool articlesRefs})
        > {
  $$SourcesTableTableManager(_$HsDatabase db, $SourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> siteUrl = const Value.absent(),
                Value<String> feedUrl = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> accentDark = const Value.absent(),
                Value<int> accentLight = const Value.absent(),
                Value<SourceType> type = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> mutedInLatest = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                Value<DateTime?> lastFetchedAt = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> failingSince = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => SourcesCompanion(
                id: id,
                title: title,
                siteUrl: siteUrl,
                feedUrl: feedUrl,
                category: category,
                accentDark: accentDark,
                accentLight: accentLight,
                type: type,
                enabled: enabled,
                sortOrder: sortOrder,
                mutedInLatest: mutedInLatest,
                etag: etag,
                lastModified: lastModified,
                lastFetchedAt: lastFetchedAt,
                addedAt: addedAt,
                failingSince: failingSince,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String?> siteUrl = const Value.absent(),
                required String feedUrl,
                required String category,
                required int accentDark,
                required int accentLight,
                required SourceType type,
                Value<bool> enabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> mutedInLatest = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                Value<DateTime?> lastFetchedAt = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> failingSince = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => SourcesCompanion.insert(
                id: id,
                title: title,
                siteUrl: siteUrl,
                feedUrl: feedUrl,
                category: category,
                accentDark: accentDark,
                accentLight: accentLight,
                type: type,
                enabled: enabled,
                sortOrder: sortOrder,
                mutedInLatest: mutedInLatest,
                etag: etag,
                lastModified: lastModified,
                lastFetchedAt: lastFetchedAt,
                addedAt: addedAt,
                failingSince: failingSince,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SourcesTable, SourceRow>(table),
                  $$SourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({articlesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (articlesRefs) db.articles],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (articlesRefs)
                    await $_getPrefetchedData<
                      SourceRow,
                      $SourcesTable,
                      ArticleRow
                    >(
                      currentTable: table,
                      referencedTable: $$SourcesTableReferences
                          ._articlesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SourcesTableReferences(db, table, p0).articlesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sourceId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$HsDatabase,
      $SourcesTable,
      SourceRow,
      $$SourcesTableFilterComposer,
      $$SourcesTableOrderingComposer,
      $$SourcesTableAnnotationComposer,
      $$SourcesTableCreateCompanionBuilder,
      $$SourcesTableUpdateCompanionBuilder,
      (SourceRow, $$SourcesTableReferences),
      SourceRow,
      PrefetchHooks Function({bool articlesRefs})
    >;
typedef $$ArticlesTableCreateCompanionBuilder = ArticlesCompanion Function({
  Value<int> id,
  required int sourceId,
  required String guid,
  required String title,
  Value<String?> summary,
  Value<String?> contentSnippet,
  Value<String?> fullContentHtml,
  required String link,
  Value<String> canonicalUrl,
  Value<String> titleKey,
  Value<String?> author,
  required DateTime publishedAt,
  Value<String?> imageUrl,
  Value<DateTime> fetchedAt,
  Value<bool> seenInLinger,
  Value<bool> readFull,
});
typedef $$ArticlesTableUpdateCompanionBuilder = ArticlesCompanion Function({
  Value<int> id,
  Value<int> sourceId,
  Value<String> guid,
  Value<String> title,
  Value<String?> summary,
  Value<String?> contentSnippet,
  Value<String?> fullContentHtml,
  Value<String> link,
  Value<String> canonicalUrl,
  Value<String> titleKey,
  Value<String?> author,
  Value<DateTime> publishedAt,
  Value<String?> imageUrl,
  Value<DateTime> fetchedAt,
  Value<bool> seenInLinger,
  Value<bool> readFull,
});

final class $$ArticlesTableReferences
    extends BaseReferences<_$HsDatabase, $ArticlesTable, ArticleRow> {
  $$ArticlesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$HsDatabase db) =>
      db.sources.createAlias('articles__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<int>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ReadEventsTable, List<ReadEventRow>>
  _readEventsRefsTable(_$HsDatabase db) => MultiTypedResultKey.fromTable(
    db.readEvents,
    aliasName: 'articles__id__read_events__article_id',
  );

  $$ReadEventsTableProcessedTableManager get readEventsRefs {
    final manager = $$ReadEventsTableTableManager(
      $_db,
      $_db.readEvents,
    ).filter((f) => f.articleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_readEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ArticlesTableFilterComposer
    extends Composer<_$HsDatabase, $ArticlesTable> {
  $$ArticlesTableFilterComposer({
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

  ColumnFilters<String> get guid => $composableBuilder(
    column: $table.guid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentSnippet => $composableBuilder(
    column: $table.contentSnippet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullContentHtml => $composableBuilder(
    column: $table.fullContentHtml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleKey => $composableBuilder(
    column: $table.titleKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get seenInLinger => $composableBuilder(
    column: $table.seenInLinger,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get readFull => $composableBuilder(
    column: $table.readFull,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> readEventsRefs(
    Expression<bool> Function($$ReadEventsTableFilterComposer f) f,
  ) {
    final $$ReadEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readEvents,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadEventsTableFilterComposer(
            $db: $db,
            $table: $db.readEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArticlesTableOrderingComposer
    extends Composer<_$HsDatabase, $ArticlesTable> {
  $$ArticlesTableOrderingComposer({
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

  ColumnOrderings<String> get guid => $composableBuilder(
    column: $table.guid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentSnippet => $composableBuilder(
    column: $table.contentSnippet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullContentHtml => $composableBuilder(
    column: $table.fullContentHtml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get link => $composableBuilder(
    column: $table.link,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleKey => $composableBuilder(
    column: $table.titleKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get seenInLinger => $composableBuilder(
    column: $table.seenInLinger,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get readFull => $composableBuilder(
    column: $table.readFull,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArticlesTableAnnotationComposer
    extends Composer<_$HsDatabase, $ArticlesTable> {
  $$ArticlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get guid =>
      $composableBuilder(column: $table.guid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get contentSnippet => $composableBuilder(
    column: $table.contentSnippet,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fullContentHtml => $composableBuilder(
    column: $table.fullContentHtml,
    builder: (column) => column,
  );

  GeneratedColumn<String> get link =>
      $composableBuilder(column: $table.link, builder: (column) => column);

  GeneratedColumn<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleKey =>
      $composableBuilder(column: $table.titleKey, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<bool> get seenInLinger => $composableBuilder(
    column: $table.seenInLinger,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get readFull =>
      $composableBuilder(column: $table.readFull, builder: (column) => column);

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> readEventsRefs<T extends Object>(
    Expression<T> Function($$ReadEventsTableAnnotationComposer a) f,
  ) {
    final $$ReadEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readEvents,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.readEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArticlesTableTableManager
    extends
        RootTableManager<
          _$HsDatabase,
          $ArticlesTable,
          ArticleRow,
          $$ArticlesTableFilterComposer,
          $$ArticlesTableOrderingComposer,
          $$ArticlesTableAnnotationComposer,
          $$ArticlesTableCreateCompanionBuilder,
          $$ArticlesTableUpdateCompanionBuilder,
          (ArticleRow, $$ArticlesTableReferences),
          ArticleRow,
          PrefetchHooks Function({bool sourceId, bool readEventsRefs})
        > {
  $$ArticlesTableTableManager(_$HsDatabase db, $ArticlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArticlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArticlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArticlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sourceId = const Value.absent(),
                Value<String> guid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> contentSnippet = const Value.absent(),
                Value<String?> fullContentHtml = const Value.absent(),
                Value<String> link = const Value.absent(),
                Value<String> canonicalUrl = const Value.absent(),
                Value<String> titleKey = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<DateTime> publishedAt = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<bool> seenInLinger = const Value.absent(),
                Value<bool> readFull = const Value.absent(),
              }) => ArticlesCompanion(
                id: id,
                sourceId: sourceId,
                guid: guid,
                title: title,
                summary: summary,
                contentSnippet: contentSnippet,
                fullContentHtml: fullContentHtml,
                link: link,
                canonicalUrl: canonicalUrl,
                titleKey: titleKey,
                author: author,
                publishedAt: publishedAt,
                imageUrl: imageUrl,
                fetchedAt: fetchedAt,
                seenInLinger: seenInLinger,
                readFull: readFull,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sourceId,
                required String guid,
                required String title,
                Value<String?> summary = const Value.absent(),
                Value<String?> contentSnippet = const Value.absent(),
                Value<String?> fullContentHtml = const Value.absent(),
                required String link,
                Value<String> canonicalUrl = const Value.absent(),
                Value<String> titleKey = const Value.absent(),
                Value<String?> author = const Value.absent(),
                required DateTime publishedAt,
                Value<String?> imageUrl = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<bool> seenInLinger = const Value.absent(),
                Value<bool> readFull = const Value.absent(),
              }) => ArticlesCompanion.insert(
                id: id,
                sourceId: sourceId,
                guid: guid,
                title: title,
                summary: summary,
                contentSnippet: contentSnippet,
                fullContentHtml: fullContentHtml,
                link: link,
                canonicalUrl: canonicalUrl,
                titleKey: titleKey,
                author: author,
                publishedAt: publishedAt,
                imageUrl: imageUrl,
                fetchedAt: fetchedAt,
                seenInLinger: seenInLinger,
                readFull: readFull,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArticlesTable, ArticleRow>(table),
                  $$ArticlesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false, readEventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (readEventsRefs) db.readEvents],
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
                    if (sourceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceId,
                        referencedTable: $$ArticlesTableReferences
                            ._sourceIdTable(db),
                        referencedColumn: $$ArticlesTableReferences
                            ._sourceIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (readEventsRefs)
                    await $_getPrefetchedData<
                      ArticleRow,
                      $ArticlesTable,
                      ReadEventRow
                    >(
                      currentTable: table,
                      referencedTable: $$ArticlesTableReferences
                          ._readEventsRefsTable(db),
                      managerFromTypedResult: (p0) => $$ArticlesTableReferences(
                        db,
                        table,
                        p0,
                      ).readEventsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.articleId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ArticlesTableProcessedTableManager =
    ProcessedTableManager<
      _$HsDatabase,
      $ArticlesTable,
      ArticleRow,
      $$ArticlesTableFilterComposer,
      $$ArticlesTableOrderingComposer,
      $$ArticlesTableAnnotationComposer,
      $$ArticlesTableCreateCompanionBuilder,
      $$ArticlesTableUpdateCompanionBuilder,
      (ArticleRow, $$ArticlesTableReferences),
      ArticleRow,
      PrefetchHooks Function({bool sourceId, bool readEventsRefs})
    >;
typedef $$ReadEventsTableCreateCompanionBuilder = ReadEventsCompanion Function({
  Value<int> id,
  required int articleId,
  required ReadMode mode,
  Value<DateTime> at,
  Value<int> dwellMs,
});
typedef $$ReadEventsTableUpdateCompanionBuilder = ReadEventsCompanion Function({
  Value<int> id,
  Value<int> articleId,
  Value<ReadMode> mode,
  Value<DateTime> at,
  Value<int> dwellMs,
});

final class $$ReadEventsTableReferences
    extends BaseReferences<_$HsDatabase, $ReadEventsTable, ReadEventRow> {
  $$ReadEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ArticlesTable _articleIdTable(_$HsDatabase db) =>
      db.articles.createAlias('read_events__article_id__articles__id');

  $$ArticlesTableProcessedTableManager get articleId {
    final $_column = $_itemColumn<int>('article_id')!;

    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_articleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReadEventsTableFilterComposer
    extends Composer<_$HsDatabase, $ReadEventsTable> {
  $$ReadEventsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<ReadMode, ReadMode, String> get mode =>
      $composableBuilder(
        column: $table.mode,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dwellMs => $composableBuilder(
    column: $table.dwellMs,
    builder: (column) => ColumnFilters(column),
  );

  $$ArticlesTableFilterComposer get articleId {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadEventsTableOrderingComposer
    extends Composer<_$HsDatabase, $ReadEventsTable> {
  $$ReadEventsTableOrderingComposer({
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

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dwellMs => $composableBuilder(
    column: $table.dwellMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$ArticlesTableOrderingComposer get articleId {
    final $$ArticlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableOrderingComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadEventsTableAnnotationComposer
    extends Composer<_$HsDatabase, $ReadEventsTable> {
  $$ReadEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReadMode, String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<int> get dwellMs =>
      $composableBuilder(column: $table.dwellMs, builder: (column) => column);

  $$ArticlesTableAnnotationComposer get articleId {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadEventsTableTableManager
    extends
        RootTableManager<
          _$HsDatabase,
          $ReadEventsTable,
          ReadEventRow,
          $$ReadEventsTableFilterComposer,
          $$ReadEventsTableOrderingComposer,
          $$ReadEventsTableAnnotationComposer,
          $$ReadEventsTableCreateCompanionBuilder,
          $$ReadEventsTableUpdateCompanionBuilder,
          (ReadEventRow, $$ReadEventsTableReferences),
          ReadEventRow,
          PrefetchHooks Function({bool articleId})
        > {
  $$ReadEventsTableTableManager(_$HsDatabase db, $ReadEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> articleId = const Value.absent(),
                Value<ReadMode> mode = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<int> dwellMs = const Value.absent(),
              }) => ReadEventsCompanion(
                id: id,
                articleId: articleId,
                mode: mode,
                at: at,
                dwellMs: dwellMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int articleId,
                required ReadMode mode,
                Value<DateTime> at = const Value.absent(),
                Value<int> dwellMs = const Value.absent(),
              }) => ReadEventsCompanion.insert(
                id: id,
                articleId: articleId,
                mode: mode,
                at: at,
                dwellMs: dwellMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadEventsTable, ReadEventRow>(table),
                  $$ReadEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({articleId = false}) {
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
                    if (articleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.articleId,
                        referencedTable: $$ReadEventsTableReferences
                            ._articleIdTable(db),
                        referencedColumn: $$ReadEventsTableReferences
                            ._articleIdTable(db)
                            .id,
                      ) as T;
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

typedef $$ReadEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$HsDatabase,
      $ReadEventsTable,
      ReadEventRow,
      $$ReadEventsTableFilterComposer,
      $$ReadEventsTableOrderingComposer,
      $$ReadEventsTableAnnotationComposer,
      $$ReadEventsTableCreateCompanionBuilder,
      $$ReadEventsTableUpdateCompanionBuilder,
      (ReadEventRow, $$ReadEventsTableReferences),
      ReadEventRow,
      PrefetchHooks Function({bool articleId})
    >;
typedef $$CaughtUpDaysTableCreateCompanionBuilder =
    CaughtUpDaysCompanion Function({required DateTime day, Value<int> rowid});
typedef $$CaughtUpDaysTableUpdateCompanionBuilder =
    CaughtUpDaysCompanion Function({Value<DateTime> day, Value<int> rowid});

class $$CaughtUpDaysTableFilterComposer
    extends Composer<_$HsDatabase, $CaughtUpDaysTable> {
  $$CaughtUpDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CaughtUpDaysTableOrderingComposer
    extends Composer<_$HsDatabase, $CaughtUpDaysTable> {
  $$CaughtUpDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CaughtUpDaysTableAnnotationComposer
    extends Composer<_$HsDatabase, $CaughtUpDaysTable> {
  $$CaughtUpDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);
}

class $$CaughtUpDaysTableTableManager
    extends
        RootTableManager<
          _$HsDatabase,
          $CaughtUpDaysTable,
          CaughtUpRow,
          $$CaughtUpDaysTableFilterComposer,
          $$CaughtUpDaysTableOrderingComposer,
          $$CaughtUpDaysTableAnnotationComposer,
          $$CaughtUpDaysTableCreateCompanionBuilder,
          $$CaughtUpDaysTableUpdateCompanionBuilder,
          (
            CaughtUpRow,
            BaseReferences<_$HsDatabase, $CaughtUpDaysTable, CaughtUpRow>,
          ),
          CaughtUpRow,
          PrefetchHooks Function()
        > {
  $$CaughtUpDaysTableTableManager(_$HsDatabase db, $CaughtUpDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CaughtUpDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CaughtUpDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CaughtUpDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<DateTime> day = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => CaughtUpDaysCompanion(day: day, rowid: rowid),
          createCompanionCallback: ({
            required DateTime day,
            Value<int> rowid = const Value.absent(),
          }) => CaughtUpDaysCompanion.insert(day: day, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CaughtUpDaysTable, CaughtUpRow>(table),
                  BaseReferences<_$HsDatabase, $CaughtUpDaysTable, CaughtUpRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CaughtUpDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$HsDatabase,
      $CaughtUpDaysTable,
      CaughtUpRow,
      $$CaughtUpDaysTableFilterComposer,
      $$CaughtUpDaysTableOrderingComposer,
      $$CaughtUpDaysTableAnnotationComposer,
      $$CaughtUpDaysTableCreateCompanionBuilder,
      $$CaughtUpDaysTableUpdateCompanionBuilder,
      (
        CaughtUpRow,
        BaseReferences<_$HsDatabase, $CaughtUpDaysTable, CaughtUpRow>,
      ),
      CaughtUpRow,
      PrefetchHooks Function()
    >;

class $HsDatabaseManager {
  final _$HsDatabase _db;
  $HsDatabaseManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db, _db.sources);
  $$ArticlesTableTableManager get articles =>
      $$ArticlesTableTableManager(_db, _db.articles);
  $$ReadEventsTableTableManager get readEvents =>
      $$ReadEventsTableTableManager(_db, _db.readEvents);
  $$CaughtUpDaysTableTableManager get caughtUpDays =>
      $$CaughtUpDaysTableTableManager(_db, _db.caughtUpDays);
}
