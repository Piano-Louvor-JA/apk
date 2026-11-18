import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_catalog_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/bible_book.dart';

class LiturgyVerseFields extends StatefulWidget {
  const LiturgyVerseFields({
    super.key,
    required this.book,
    required this.chapter,
    required this.numbers,
  });
  final ValueNotifier<int?> book;
  final ValueNotifier<int?> chapter;
  final TextEditingController numbers;
  @override
  State<LiturgyVerseFields> createState() => _LiturgyVerseFieldsState();
}

class _LiturgyVerseFieldsState extends State<LiturgyVerseFields> {
  Future<List<BibleBook>>? _books;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _books ??= LiturgyCatalogRepository.open(
      EasyLocalization.of(context)?.locale.languageCode ?? 'pt',
    ).then((repo) => repo.getBooks());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<BibleBook>>(
    future: _books,
    builder: (context, snapshot) {
      final books = snapshot.data ?? const <BibleBook>[];
      final current = books.where((e) => e.id == widget.book.value).firstOrNull;
      return Column(
        children: [
          if (snapshot.connectionState != ConnectionState.done)
            const LinearProgressIndicator(),
          if (snapshot.hasError) Text('liturgy.parity.catalogUnavailable'.tr()),
          DropdownButtonFormField<int>(
            initialValue: current?.id,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'liturgy.parity.book'.tr()),
            items: [
              for (final book in books)
                DropdownMenuItem(value: book.id, child: Text(book.name)),
            ],
            onChanged: (value) => setState(() {
              widget.book.value = value;
              widget.chapter.value = 1;
            }),
          ),
          DropdownButtonFormField<int>(
            key: ValueKey('chapter-${current?.id}'),
            initialValue:
                current != null &&
                    widget.chapter.value != null &&
                    widget.chapter.value! <= current.chapters
                ? widget.chapter.value
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'liturgy.parity.chapter'.tr(),
            ),
            items: [
              for (var i = 1; i <= (current?.chapters ?? 0); i++)
                DropdownMenuItem(value: i, child: Text('$i')),
            ],
            onChanged: (value) => setState(() => widget.chapter.value = value),
          ),
          TextField(
            controller: widget.numbers,
            decoration: InputDecoration(
              labelText: 'liturgy.parity.verses'.tr(),
              hintText: '1-3,5',
            ),
          ),
        ],
      );
    },
  );
}
