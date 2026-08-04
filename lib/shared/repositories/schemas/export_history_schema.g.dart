// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'export_history_schema.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetExportHistorySchemaCollection on Isar {
  IsarCollection<ExportHistorySchema> get exportHistorySchemas =>
      this.collection();
}

const ExportHistorySchemaSchema = CollectionSchema(
  name: r'ExportHistorySchema',
  id: 5376072457810733752,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'durationMs': PropertySchema(
      id: 1,
      name: r'durationMs',
      type: IsarType.long,
    ),
    r'outputFrameCount': PropertySchema(
      id: 2,
      name: r'outputFrameCount',
      type: IsarType.long,
    ),
    r'outputPath': PropertySchema(
      id: 3,
      name: r'outputPath',
      type: IsarType.string,
    ),
    r'outputSizeBytes': PropertySchema(
      id: 4,
      name: r'outputSizeBytes',
      type: IsarType.long,
    ),
    r'settingsJson': PropertySchema(
      id: 5,
      name: r'settingsJson',
      type: IsarType.string,
    ),
    r'sourceDurationMs': PropertySchema(
      id: 6,
      name: r'sourceDurationMs',
      type: IsarType.long,
    ),
    r'videoPath': PropertySchema(
      id: 7,
      name: r'videoPath',
      type: IsarType.string,
    ),
  },

  estimateSize: _exportHistorySchemaEstimateSize,
  serialize: _exportHistorySchemaSerialize,
  deserialize: _exportHistorySchemaDeserialize,
  deserializeProp: _exportHistorySchemaDeserializeProp,
  idName: r'id',
  indexes: {
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

  getId: _exportHistorySchemaGetId,
  getLinks: _exportHistorySchemaGetLinks,
  attach: _exportHistorySchemaAttach,
  version: '3.3.2',
);

int _exportHistorySchemaEstimateSize(
  ExportHistorySchema object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.outputPath.length * 3;
  bytesCount += 3 + object.settingsJson.length * 3;
  bytesCount += 3 + object.videoPath.length * 3;
  return bytesCount;
}

void _exportHistorySchemaSerialize(
  ExportHistorySchema object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeLong(offsets[1], object.durationMs);
  writer.writeLong(offsets[2], object.outputFrameCount);
  writer.writeString(offsets[3], object.outputPath);
  writer.writeLong(offsets[4], object.outputSizeBytes);
  writer.writeString(offsets[5], object.settingsJson);
  writer.writeLong(offsets[6], object.sourceDurationMs);
  writer.writeString(offsets[7], object.videoPath);
}

ExportHistorySchema _exportHistorySchemaDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ExportHistorySchema();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.durationMs = reader.readLong(offsets[1]);
  object.id = id;
  object.outputFrameCount = reader.readLongOrNull(offsets[2]);
  object.outputPath = reader.readString(offsets[3]);
  object.outputSizeBytes = reader.readLong(offsets[4]);
  object.settingsJson = reader.readString(offsets[5]);
  object.sourceDurationMs = reader.readLong(offsets[6]);
  object.videoPath = reader.readString(offsets[7]);
  return object;
}

P _exportHistorySchemaDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _exportHistorySchemaGetId(ExportHistorySchema object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _exportHistorySchemaGetLinks(
  ExportHistorySchema object,
) {
  return [];
}

void _exportHistorySchemaAttach(
  IsarCollection<dynamic> col,
  Id id,
  ExportHistorySchema object,
) {
  object.id = id;
}

extension ExportHistorySchemaQueryWhereSort
    on QueryBuilder<ExportHistorySchema, ExportHistorySchema, QWhere> {
  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterWhere>
  anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }
}

extension ExportHistorySchemaQueryWhere
    on QueryBuilder<ExportHistorySchema, ExportHistorySchema, QWhereClause> {
  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterWhereClause>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterWhereClause>
  idBetween(
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterWhereClause>
  createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'createdAt', value: [createdAt]),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterWhereClause>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterWhereClause>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterWhereClause>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterWhereClause>
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

extension ExportHistorySchemaQueryFilter
    on
        QueryBuilder<
          ExportHistorySchema,
          ExportHistorySchema,
          QFilterCondition
        > {
  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  durationMsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'durationMs', value: value),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  durationMsGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'durationMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  durationMsLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'durationMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  durationMsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'durationMs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputFrameCountIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'outputFrameCount'),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputFrameCountIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'outputFrameCount'),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputFrameCountEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'outputFrameCount', value: value),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputFrameCountGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'outputFrameCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputFrameCountLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'outputFrameCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputFrameCountBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'outputFrameCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputPathEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputPathGreaterThan(
    String value, {
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputPathLessThan(
    String value, {
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputPathBetween(
    String lower,
    String upper, {
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'outputPath', value: ''),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'outputPath', value: ''),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputSizeBytesEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'outputSizeBytes', value: value),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputSizeBytesGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'outputSizeBytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputSizeBytesLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'outputSizeBytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  outputSizeBytesBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'outputSizeBytes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  settingsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'settingsJson', value: ''),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  settingsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'settingsJson', value: ''),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  sourceDurationMsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sourceDurationMs', value: value),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  sourceDurationMsGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sourceDurationMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  sourceDurationMsLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sourceDurationMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  sourceDurationMsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sourceDurationMs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
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

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  videoPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'videoPath', value: ''),
      );
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterFilterCondition>
  videoPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'videoPath', value: ''),
      );
    });
  }
}

extension ExportHistorySchemaQueryObject
    on
        QueryBuilder<
          ExportHistorySchema,
          ExportHistorySchema,
          QFilterCondition
        > {}

extension ExportHistorySchemaQueryLinks
    on
        QueryBuilder<
          ExportHistorySchema,
          ExportHistorySchema,
          QFilterCondition
        > {}

extension ExportHistorySchemaQuerySortBy
    on QueryBuilder<ExportHistorySchema, ExportHistorySchema, QSortBy> {
  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortByDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMs', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortByDurationMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMs', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortByOutputFrameCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputFrameCount', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortByOutputFrameCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputFrameCount', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortByOutputPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputPath', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortByOutputPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputPath', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortByOutputSizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputSizeBytes', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortByOutputSizeBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputSizeBytes', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortBySettingsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settingsJson', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortBySettingsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settingsJson', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortBySourceDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceDurationMs', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortBySourceDurationMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceDurationMs', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortByVideoPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'videoPath', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  sortByVideoPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'videoPath', Sort.desc);
    });
  }
}

extension ExportHistorySchemaQuerySortThenBy
    on QueryBuilder<ExportHistorySchema, ExportHistorySchema, QSortThenBy> {
  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenByDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMs', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenByDurationMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMs', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenByOutputFrameCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputFrameCount', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenByOutputFrameCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputFrameCount', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenByOutputPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputPath', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenByOutputPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputPath', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenByOutputSizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputSizeBytes', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenByOutputSizeBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputSizeBytes', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenBySettingsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settingsJson', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenBySettingsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settingsJson', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenBySourceDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceDurationMs', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenBySourceDurationMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceDurationMs', Sort.desc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenByVideoPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'videoPath', Sort.asc);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QAfterSortBy>
  thenByVideoPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'videoPath', Sort.desc);
    });
  }
}

extension ExportHistorySchemaQueryWhereDistinct
    on QueryBuilder<ExportHistorySchema, ExportHistorySchema, QDistinct> {
  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QDistinct>
  distinctByDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'durationMs');
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QDistinct>
  distinctByOutputFrameCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'outputFrameCount');
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QDistinct>
  distinctByOutputPath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'outputPath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QDistinct>
  distinctByOutputSizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'outputSizeBytes');
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QDistinct>
  distinctBySettingsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'settingsJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QDistinct>
  distinctBySourceDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceDurationMs');
    });
  }

  QueryBuilder<ExportHistorySchema, ExportHistorySchema, QDistinct>
  distinctByVideoPath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'videoPath', caseSensitive: caseSensitive);
    });
  }
}

extension ExportHistorySchemaQueryProperty
    on QueryBuilder<ExportHistorySchema, ExportHistorySchema, QQueryProperty> {
  QueryBuilder<ExportHistorySchema, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ExportHistorySchema, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<ExportHistorySchema, int, QQueryOperations>
  durationMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'durationMs');
    });
  }

  QueryBuilder<ExportHistorySchema, int?, QQueryOperations>
  outputFrameCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'outputFrameCount');
    });
  }

  QueryBuilder<ExportHistorySchema, String, QQueryOperations>
  outputPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'outputPath');
    });
  }

  QueryBuilder<ExportHistorySchema, int, QQueryOperations>
  outputSizeBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'outputSizeBytes');
    });
  }

  QueryBuilder<ExportHistorySchema, String, QQueryOperations>
  settingsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'settingsJson');
    });
  }

  QueryBuilder<ExportHistorySchema, int, QQueryOperations>
  sourceDurationMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceDurationMs');
    });
  }

  QueryBuilder<ExportHistorySchema, String, QQueryOperations>
  videoPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'videoPath');
    });
  }
}
