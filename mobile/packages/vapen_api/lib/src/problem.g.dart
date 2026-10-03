// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'problem.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiProblem _$ApiProblemFromJson(Map<String, dynamic> json) => ApiProblem(
  type: json['type'] as String,
  title: json['title'] as String,
  status: (json['status'] as num).toInt(),
  code: json['code'] as String,
  detail: json['detail'] as String?,
  errors: (json['errors'] as List<dynamic>?)
      ?.map((e) => ApiFieldError.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ApiProblemToJson(ApiProblem instance) =>
    <String, dynamic>{
      'type': instance.type,
      'title': instance.title,
      'status': instance.status,
      'code': instance.code,
      'detail': instance.detail,
      'errors': instance.errors,
    };

ApiFieldError _$ApiFieldErrorFromJson(Map<String, dynamic> json) =>
    ApiFieldError(
      field: json['field'] as String,
      message: json['message'] as String,
    );

Map<String, dynamic> _$ApiFieldErrorToJson(ApiFieldError instance) =>
    <String, dynamic>{'field': instance.field, 'message': instance.message};
