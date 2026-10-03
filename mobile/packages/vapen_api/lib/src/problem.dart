import 'package:json_annotation/json_annotation.dart';

part 'problem.g.dart';

@JsonSerializable()
class ApiProblem {
  ApiProblem({
    required this.type,
    required this.title,
    required this.status,
    required this.code,
    this.detail,
    this.errors,
  });

  final String type;
  final String title;
  final int status;
  final String code;
  final String? detail;
  final List<ApiFieldError>? errors;

  factory ApiProblem.fromJson(Map<String, dynamic> json) =>
      _$ApiProblemFromJson(json);
  Map<String, dynamic> toJson() => _$ApiProblemToJson(this);
}

@JsonSerializable()
class ApiFieldError {
  ApiFieldError({required this.field, required this.message});

  final String field;
  final String message;

  factory ApiFieldError.fromJson(Map<String, dynamic> json) =>
      _$ApiFieldErrorFromJson(json);
  Map<String, dynamic> toJson() => _$ApiFieldErrorToJson(this);
}

class VapenApiException implements Exception {
  VapenApiException(this.problem, {this.retryAfterSeconds});

  final ApiProblem problem;
  final int? retryAfterSeconds;

  @override
  String toString() => 'VapenApiException(${problem.code}: ${problem.detail ?? problem.title})';
}
