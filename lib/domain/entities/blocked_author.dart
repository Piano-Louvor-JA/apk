/// Autor bloqueado pelo usuário (App Store 1.2 — conteúdo gerado por usuários).
class BlockedAuthor {
  final int id;
  final String name;

  const BlockedAuthor({required this.id, required this.name});

  factory BlockedAuthor.fromJson(Map<String, dynamic> json) => BlockedAuthor(
    id: (json['id_user'] as num).toInt(),
    name: (json['displayName'] as String?)?.trim().isNotEmpty == true
        ? json['displayName'] as String
        : 'Autor sem nome',
  );
}
