// Itens agendados (calendário) portados do LouvorJA Delphi.
library;

/// Categoria de itens agendados (itensAgendadosCategorias.xml).
class ScheduledCategory {
  const ScheduledCategory({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory ScheduledCategory.fromJson(Map<String, dynamic> json) =>
      ScheduledCategory(id: json['id'] as String, name: json['name'] as String);
}

/// Item agendado (itensAgendados.xml): um arquivo/roteiro para uma data,
/// agrupado por categoria.
class ScheduledItem {
  const ScheduledItem({
    required this.id,
    required this.categoryId,
    required this.date,
    required this.name,
    this.filePath = '',
    this.isRelativePath = false,
    this.notes = '',
  });

  final String id;
  final String categoryId;
  final DateTime date;
  final String name;

  /// Caminho original do Delphi (Windows) ou URL — pode não existir no
  /// dispositivo; a UI oferece "adicionar arquivo" quando não existe.
  final String filePath;

  /// ARQUIVO_INFO == 'I' no Delphi: caminho relativo ao dir do exe.
  final bool isRelativePath;

  /// Observações de equipe — extensão NOSSA (Delphi não tem o campo).
  final String notes;

  ScheduledItem copyWith({String? notes, String? filePath}) => ScheduledItem(
    id: id,
    categoryId: categoryId,
    date: date,
    name: name,
    filePath: filePath ?? this.filePath,
    isRelativePath: isRelativePath,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'date': date.toIso8601String(),
    'name': name,
    'filePath': filePath,
    'isRelativePath': isRelativePath,
    'notes': notes,
  };

  factory ScheduledItem.fromJson(Map<String, dynamic> json) => ScheduledItem(
    id: json['id'] as String,
    categoryId: json['categoryId'] as String,
    date: DateTime.parse(json['date'] as String),
    name: json['name'] as String,
    filePath: (json['filePath'] as String?) ?? '',
    isRelativePath: (json['isRelativePath'] as bool?) ?? false,
    notes: (json['notes'] as String?) ?? '',
  );
}
