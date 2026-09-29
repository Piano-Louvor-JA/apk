library;

import 'package:flutter/foundation.dart';

/// Testamento: Antigo (OT) ou Novo (NT).
enum BibleTestament { ot, nt }

/// Tom visual do tile do livro (faixas canônicas).
enum BibleBookTone { law, history, prophets, gospels, letters, neutral }

/// Livro bíblico (registro do catálogo).
@immutable
class BibleBook {
  final int id;
  final String name;
  final String abbreviation;
  final int chapters;
  final int bookNumber;
  final String languageId;

  /// Cor canonica fornecida pela API/web para manter paridade visual.
  final String? color;

  const BibleBook({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.chapters,
    required this.bookNumber,
    this.languageId = 'pt',
    this.color,
  });

  factory BibleBook.fromJson(Map<String, dynamic> json) {
    return BibleBook(
      id: _parseInt(json['id_bible_book']),
      name: (json['name'] ?? '').toString(),
      abbreviation: (json['abbreviation'] ?? '').toString(),
      chapters: _parseInt(json['chapters']),
      bookNumber: _parseInt(json['book_number']),
      languageId: (json['id_language'] ?? 'pt').toString(),
      color: json['color']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id_bible_book': id,
    'name': name,
    'abbreviation': abbreviation,
    'chapters': chapters,
    'book_number': bookNumber,
    'id_language': languageId,
  };

  /// Testamento baseado no bookNumber (1-39 = OT, 40-66 = NT).
  BibleTestament get testament =>
      bookNumber <= 39 ? BibleTestament.ot : BibleTestament.nt;

  /// Tom visual conforme faixas canônicas.
  BibleBookTone get tone {
    if (bookNumber <= 5) return BibleBookTone.law;
    if (bookNumber <= 17) return BibleBookTone.history;
    if (bookNumber <= 39) return BibleBookTone.prophets;
    if (bookNumber <= 43) return BibleBookTone.gospels;
    if (bookNumber <= 66) return BibleBookTone.letters;
    return BibleBookTone.neutral;
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleBook && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'BibleBook(id: $id, name: $name, abbreviation: $abbreviation, chapters: $chapters, bookNumber: $bookNumber)';
}
