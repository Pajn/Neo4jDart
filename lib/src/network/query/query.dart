import 'package:json_annotation/json_annotation.dart';
import 'statement.dart';

part 'query.g.dart';

@JsonSerializable()
class Query {
  final List<Statement> statements;

  Query({required this.statements});

  Map<String, dynamic> toJson() => _$QueryToJson(this);
  factory Query.fromJson(Map<String, dynamic> json) => _$QueryFromJson(json);
}
