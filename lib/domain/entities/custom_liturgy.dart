import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';

part 'custom_liturgy.freezed.dart';

/// Contrato CustomLiturgy do desktop: roteiro nomeado, independente da semana.
@Freezed(fromJson: false, toJson: false)
abstract class CustomLiturgy with _$CustomLiturgy {
  const CustomLiturgy._();
  const factory CustomLiturgy({
    required String id,
    required String name,
    @Default([]) List<LiturgyItem> items,
    @Default('') String notes,
    String? startTime,
    String? endTime,
  }) = _CustomLiturgy;
  factory CustomLiturgy.fromJson(Map<String, dynamic> json) => CustomLiturgy(
    id: json['id'] as String,
    name: json['name'] as String,
    items: (json['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => LiturgyItem.fromJson(e.cast<String, dynamic>()))
        .toList(),
    notes: json['notes'] as String? ?? '',
    startTime: json['startTime'] as String?,
    endTime: json['endTime'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((e) => e.toJson()).toList(),
    'notes': notes,
    'startTime': startTime,
    'endTime': endTime,
  };
}
