import 'parameters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'statement.g.dart';

@JsonSerializable()
class Statement {
  final String statement;
  final Parameters? parameters;

  Statement({required this.statement, this.parameters});

  Map<String, dynamic> toJson() => _$StatementToJson(this);
  factory Statement.fromJson(Map<String, dynamic> json) =>
      _$StatementFromJson(json);
}
