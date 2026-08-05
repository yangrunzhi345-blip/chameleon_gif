// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'export_task_schema.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetExportTaskSchemaCollection on Isar {
  IsarCollection<ExportTaskSchema> get exportTaskSchemas => this.collection();
}

const ExportTaskSchemaSchema = CollectionSchema(
  name: r'ExportTaskSchema',
  id: -2616128915424037454,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'errorCode': PropertySchema(
      id: 1,
      name: r'errorCode',
      type: IsarType.string,
    ),
    r'errorDetail': PropertySchema(
      id: 2,
      name: r'errorDetail',
      type: IsarType.string,
    ),
    r'finishedAt': PropertySchema(
      id: 3,
      name: r'finishedAt',
      type: IsarType.dateTime,
    ),
    r'galleryMessage': PropertySchema(
      id: 4,
      name: r'galleryMessage',
      type: IsarType.string,
    ),
    r'galleryPath': PropertySchema(
      id: 5,
      name: r'galleryPath',
      type: IsarType.string,
    ),
    r'galleryStatus': PropertySchema(
      id: 6,
      name: r'galleryStatus',
      type: IsarType.long,
    ),
    r'galleryUri': PropertySchema(
      id: 7,
      name: r'galleryUri',
      type: IsarType.string,
    ),
    r'imagePathsJson': PropertySchema(
      id: 8,
      name: r'imagePathsJson',
      type: IsarType.string,
    ),
    r'outputPath': PropertySchema(
      id: 9,
      name: r'outputPath',
      type: IsarType.string,
    ),
    r'progress': PropertySchema(
      id: 10,
      name: r'progress',
      type: IsarType.double,
    ),
    r'retryCount': PropertySchema(
      id: 11,
      name: r'retryCount',
      type: IsarType.long,
    ),
    r'settingsJson': PropertySchema(
      id: 12,
      name: r'settingsJson',
      type: IsarType.string,
    ),
    r'startedAt': PropertySchema(
      id: 13,
      name: r'startedAt',
      type: IsarType.dateTime,
    ),
    r'state': PropertySchema(id: 14, name: r'state', type: IsarType.long),
    r'videoPath': PropertySchema(
      id: 15,
      name: r'videoPath',
      type: IsarType.string,
    ),
  },

  estimateSize: _exportTaskSchemaEstimateSize,
  serialize: _exportTaskSchemaSerialize,
  deserialize: _exportTaskSchemaDeserialize,
  deserializeProp: _exportTaskSchemaDeserializeProp,
  idName: r'id',
  indexes: {
    r'state': IndexSchema(
      id: 7917036384617311412,
      name: r'state',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'state',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'createdAt': IndexSchema(
      id: -3433535483987302584,
      name: r'createdAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _exportTaskSchemaGetId,
  getLinks: _exportTaskSchemaGetLinks,
  attach: _exportTaskSchemaAttach,
  version: '3.3.2',
);

int _exportTaskSchemaEstimateSize(
  ExportTaskSchema object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.errorCode;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.errorDetail;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.galleryMessage;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.galleryPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.galleryUri;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.imagePathsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.outputPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.settingsJson.length * 3;
  bytesCount += 3 + object.videoPath.length * 3;
  return bytesCount;
}

void _exportTaskSchemaSerialize(
  ExportTaskSchema object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.errorCode);
  writer.writeString(offsets[2], object.errorDetail);
  writer.writeDateTime(offsets[3], object.finishedAt);
  writer.writeString(offsets[4], object.galleryMessage);
  writer.writeString(offsets[5], object.galleryPath);
  writer.writeLong(offsets[6], object.galleryStatus);
  writer.writeString(offsets[7], object.galleryUri);
  writer.writeString(offsets[8], object.imagePathsJson);
  writer.writeString(offsets[9], object.outputPath);
  writer.writeDouble(offsets[10], object.progress);
  writer.writeLong(offsets[11], object.retryCount);
  writer.writeString(offsets[12], object.settingsJson);
  writer.writeDateTime(offsets[13], object.startedAt);
  writer.writeLong(offsets[14], object.state);
  writer.writeString(offsets[15], object.videoPath);
}

ExportTaskSchema _exportTaskSchemaDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ExportTaskSchema();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.errorCode = reader.readStringOrNull(offsets[1]);
  object.errorDetail = reader.readStringOrNull(offsets[2]);
  object.finishedAt = reader.readDateTimeOrNull(offsets[3]);
  object.galleryMessage = reader.readStringOrNull(offsets[4]);
  object.galleryPath = reader.readStringOrNull(offsets[5]);
  object.galleryStatus = reader.readLong(offsets[6]);
  object.galleryUri = reader.readStringOrNull(offsets[7]);
  object.id = id;
  object.imagePathsJson = reader.readStringOrNull(offsets[8]);
  object.outputPath = reader.readStringOrNull(offsets[9]);
  object.progress = reader.readDouble(offsets[10]);
  object.retryCount = reader.readLong(offsets[11]);
  object.settingsJson = reader.readString(offsets[12]);
  object.startedAt = reader.readDateTimeOrNull(offsets[13]);
  object.state = reader.readLong(offsets[14]);
  object.videoPath = reader.readString(offsets[15]);
  return object;
}

P _exportTaskSchemaDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readDouble(offset)) as P;
    case 11:
      return (reader.readLong(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 14:
      return (reader.readLong(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _exportTaskSchemaGetId(ExportTaskSchema object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _exportTaskSchemaGetLinks(ExportTaskSchema object) {
  return [];
}

void _exportTaskSchemaAttach(
  IsarCollection<dynamic> col,
  Id id,
  ExportTaskSchema object,
) {
  object.id = id;
}

extension ExportTaskSchemaQueryWhereSort
    on QueryBuilder<ExportTaskSchema, ExportTaskSchema, QWhere> {
  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhere> anyState() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'state'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }
}

extension ExportTaskSchemaQueryWhere
    on QueryBuilder<ExportTaskSchema, ExportTaskSchema, QWhereClause> {
  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause>
  stateEqualTo(int state) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'state', value: [state]),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause>
  stateNotEqualTo(int state) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [],
                upper: [state],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [state],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [state],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [],
                upper: [state],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause>
  stateGreaterThan(int state, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'state',
          lower: [state],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause>
  stateLessThan(int state, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'state',
          lower: [],
          upper: [state],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause>
  stateBetween(
    int lowerState,
    int upperState, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'state',
          lower: [lowerState],
          includeLower: includeLower,
          upper: [upperState],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause>
  createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'createdAt', value: [createdAt]),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause>
  createdAtNotEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [],
                upper: [createdAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [createdAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [createdAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [],
                upper: [createdAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause>
  createdAtGreaterThan(DateTime createdAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'createdAt',
          lower: [createdAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause>
  createdAtLessThan(DateTime createdAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'createdAt',
          lower: [],
          upper: [createdAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterWhereClause>
  createdAtBetween(
    DateTime lowerCreatedAt,
    DateTime upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'createdAt',
          lower: [lowerCreatedAt],
          includeLower: includeLower,
          upper: [upperCreatedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ExportTaskSchemaQueryFilter
    on QueryBuilder<ExportTaskSchema, ExportTaskSchema, QFilterCondition> {
  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'errorCode'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorCodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'errorCode'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorCodeEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'errorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorCodeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'errorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorCodeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'errorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorCodeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'errorCode',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorCodeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'errorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorCodeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'errorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'errorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'errorCode',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'errorCode', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'errorCode', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorDetailIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'errorDetail'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorDetailIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'errorDetail'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorDetailEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'errorDetail',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorDetailGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'errorDetail',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorDetailLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'errorDetail',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorDetailBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'errorDetail',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorDetailStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'errorDetail',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorDetailEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'errorDetail',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorDetailContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'errorDetail',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorDetailMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'errorDetail',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorDetailIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'errorDetail', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  errorDetailIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'errorDetail', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  finishedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'finishedAt'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  finishedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'finishedAt'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  finishedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'finishedAt', value: value),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  finishedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'finishedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  finishedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'finishedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  finishedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'finishedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryMessageIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'galleryMessage'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryMessageIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'galleryMessage'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryMessageEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'galleryMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryMessageGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'galleryMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryMessageLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'galleryMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryMessageBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'galleryMessage',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryMessageStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'galleryMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryMessageEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'galleryMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryMessageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'galleryMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryMessageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'galleryMessage',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryMessageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'galleryMessage', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryMessageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'galleryMessage', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'galleryPath'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'galleryPath'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryPathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'galleryPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'galleryPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'galleryPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'galleryPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'galleryPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'galleryPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'galleryPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'galleryPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'galleryPath', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'galleryPath', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryStatusEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'galleryStatus', value: value),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryStatusGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'galleryStatus',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryStatusLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'galleryStatus',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryStatusBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'galleryStatus',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryUriIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'galleryUri'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryUriIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'galleryUri'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryUriEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'galleryUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryUriGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'galleryUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryUriLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'galleryUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryUriBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'galleryUri',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryUriStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'galleryUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryUriEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'galleryUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryUriContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'galleryUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryUriMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'galleryUri',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryUriIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'galleryUri', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  galleryUriIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'galleryUri', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  imagePathsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'imagePathsJson'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  imagePathsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'imagePathsJson'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  imagePathsJsonEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'imagePathsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  imagePathsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'imagePathsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  imagePathsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'imagePathsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  imagePathsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'imagePathsJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  imagePathsJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'imagePathsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  imagePathsJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'imagePathsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  imagePathsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'imagePathsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  imagePathsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'imagePathsJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  imagePathsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'imagePathsJson', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  imagePathsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'imagePathsJson', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  outputPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'outputPath'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  outputPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'outputPath'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  outputPathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'outputPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  outputPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'outputPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  outputPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'outputPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  outputPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'outputPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  outputPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'outputPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  outputPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'outputPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  outputPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'outputPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  outputPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'outputPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  outputPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'outputPath', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  outputPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'outputPath', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  progressEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'progress',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  progressGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'progress',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  progressLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'progress',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  progressBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'progress',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  retryCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'retryCount', value: value),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  retryCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'retryCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  retryCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'retryCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  retryCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'retryCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  settingsJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'settingsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  settingsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'settingsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  settingsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'settingsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  settingsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'settingsJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  settingsJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'settingsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  settingsJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'settingsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  settingsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'settingsJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  settingsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'settingsJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  settingsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'settingsJson', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  settingsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'settingsJson', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  startedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'startedAt'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  startedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'startedAt'),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  startedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'startedAt', value: value),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  startedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'startedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  startedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'startedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  startedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'startedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  stateEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'state', value: value),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  stateGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'state',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  stateLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'state',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  stateBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'state',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  videoPathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'videoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  videoPathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'videoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  videoPathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'videoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  videoPathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'videoPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  videoPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'videoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  videoPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'videoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  videoPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'videoPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  videoPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'videoPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  videoPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'videoPath', value: ''),
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterFilterCondition>
  videoPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'videoPath', value: ''),
      );
    });
  }
}

extension ExportTaskSchemaQueryObject
    on QueryBuilder<ExportTaskSchema, ExportTaskSchema, QFilterCondition> {}

extension ExportTaskSchemaQueryLinks
    on QueryBuilder<ExportTaskSchema, ExportTaskSchema, QFilterCondition> {}

extension ExportTaskSchemaQuerySortBy
    on QueryBuilder<ExportTaskSchema, ExportTaskSchema, QSortBy> {
  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByErrorCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorCode', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByErrorCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorCode', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByErrorDetail() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorDetail', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByErrorDetailDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorDetail', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByFinishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'finishedAt', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByFinishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'finishedAt', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByGalleryMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryMessage', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByGalleryMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryMessage', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByGalleryPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryPath', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByGalleryPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryPath', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByGalleryStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryStatus', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByGalleryStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryStatus', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByGalleryUri() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryUri', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByGalleryUriDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryUri', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByImagePathsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePathsJson', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByImagePathsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePathsJson', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByOutputPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputPath', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByOutputPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputPath', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByProgressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByRetryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortBySettingsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settingsJson', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortBySettingsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settingsJson', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByStartedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByStartedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy> sortByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByVideoPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'videoPath', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  sortByVideoPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'videoPath', Sort.desc);
    });
  }
}

extension ExportTaskSchemaQuerySortThenBy
    on QueryBuilder<ExportTaskSchema, ExportTaskSchema, QSortThenBy> {
  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByErrorCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorCode', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByErrorCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorCode', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByErrorDetail() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorDetail', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByErrorDetailDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorDetail', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByFinishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'finishedAt', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByFinishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'finishedAt', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByGalleryMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryMessage', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByGalleryMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryMessage', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByGalleryPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryPath', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByGalleryPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryPath', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByGalleryStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryStatus', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByGalleryStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryStatus', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByGalleryUri() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryUri', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByGalleryUriDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'galleryUri', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByImagePathsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePathsJson', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByImagePathsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePathsJson', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByOutputPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputPath', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByOutputPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputPath', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByProgressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByRetryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenBySettingsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settingsJson', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenBySettingsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settingsJson', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByStartedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByStartedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startedAt', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy> thenByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByVideoPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'videoPath', Sort.asc);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QAfterSortBy>
  thenByVideoPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'videoPath', Sort.desc);
    });
  }
}

extension ExportTaskSchemaQueryWhereDistinct
    on QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct> {
  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByErrorCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'errorCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByErrorDetail({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'errorDetail', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByFinishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'finishedAt');
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByGalleryMessage({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'galleryMessage',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByGalleryPath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'galleryPath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByGalleryStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'galleryStatus');
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByGalleryUri({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'galleryUri', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByImagePathsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'imagePathsJson',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByOutputPath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'outputPath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'progress');
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retryCount');
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctBySettingsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'settingsJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByStartedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startedAt');
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state');
    });
  }

  QueryBuilder<ExportTaskSchema, ExportTaskSchema, QDistinct>
  distinctByVideoPath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'videoPath', caseSensitive: caseSensitive);
    });
  }
}

extension ExportTaskSchemaQueryProperty
    on QueryBuilder<ExportTaskSchema, ExportTaskSchema, QQueryProperty> {
  QueryBuilder<ExportTaskSchema, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ExportTaskSchema, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<ExportTaskSchema, String?, QQueryOperations>
  errorCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'errorCode');
    });
  }

  QueryBuilder<ExportTaskSchema, String?, QQueryOperations>
  errorDetailProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'errorDetail');
    });
  }

  QueryBuilder<ExportTaskSchema, DateTime?, QQueryOperations>
  finishedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'finishedAt');
    });
  }

  QueryBuilder<ExportTaskSchema, String?, QQueryOperations>
  galleryMessageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'galleryMessage');
    });
  }

  QueryBuilder<ExportTaskSchema, String?, QQueryOperations>
  galleryPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'galleryPath');
    });
  }

  QueryBuilder<ExportTaskSchema, int, QQueryOperations>
  galleryStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'galleryStatus');
    });
  }

  QueryBuilder<ExportTaskSchema, String?, QQueryOperations>
  galleryUriProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'galleryUri');
    });
  }

  QueryBuilder<ExportTaskSchema, String?, QQueryOperations>
  imagePathsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imagePathsJson');
    });
  }

  QueryBuilder<ExportTaskSchema, String?, QQueryOperations>
  outputPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'outputPath');
    });
  }

  QueryBuilder<ExportTaskSchema, double, QQueryOperations> progressProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'progress');
    });
  }

  QueryBuilder<ExportTaskSchema, int, QQueryOperations> retryCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retryCount');
    });
  }

  QueryBuilder<ExportTaskSchema, String, QQueryOperations>
  settingsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'settingsJson');
    });
  }

  QueryBuilder<ExportTaskSchema, DateTime?, QQueryOperations>
  startedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startedAt');
    });
  }

  QueryBuilder<ExportTaskSchema, int, QQueryOperations> stateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state');
    });
  }

  QueryBuilder<ExportTaskSchema, String, QQueryOperations> videoPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'videoPath');
    });
  }
}
