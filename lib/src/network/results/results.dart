import 'package:json_annotation/json_annotation.dart';

import 'result.dart';

part 'results.g.dart';

@JsonSerializable()
class Results {
  final List<Result> results;

  Results({required this.results});

  Map<String, dynamic> toJson() => _$ResultsToJson(this);
  factory Results.fromJson(Map<String, dynamic> json) =>
      _$ResultsFromJson(json);
}
