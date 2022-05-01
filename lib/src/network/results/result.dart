import 'package:json_annotation/json_annotation.dart';

import 'data.dart';

part 'result.g.dart';

@JsonSerializable()
class Result {
  final List columns;
  final List<Data> data;

  Result({required this.columns, required this.data});

  factory Result.fromJson(Map<String, dynamic> json) => _$ResultFromJson(json);
  Map<String, dynamic> toJson() => _$ResultToJson(this);
}
