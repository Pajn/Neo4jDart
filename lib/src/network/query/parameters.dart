import 'package:json_annotation/json_annotation.dart';

part 'parameters.g.dart';

@JsonSerializable()
class Parameters {
  final Map<String, String> props;

  Parameters({required this.props});

  Map<String, dynamic> toJson() => _$ParametersToJson(this);
  factory Parameters.fromJson(Map<String, dynamic> json) =>
      _$ParametersFromJson(json);
}
