/// Sessão do usuário custom (auth e-mail+senha da API /v1/custom).
class CustomUser {
  final int idUser;
  final String email;
  final String displayName;

  const CustomUser({
    required this.idUser,
    required this.email,
    required this.displayName,
  });

  factory CustomUser.fromJson(Map<String, dynamic> json) => CustomUser(
    idUser: (json['id_user'] as num?)?.toInt() ?? 0,
    email: json['email'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id_user': idUser,
    'email': email,
    'displayName': displayName,
  };
}

/// Sessão ativa: token opaco + dados do usuário.
class CustomSession {
  final String token;
  final CustomUser user;

  const CustomSession({required this.token, required this.user});
}

/// Erros de auth com código estável pra UI.
class CustomAuthException implements Exception {
  final String code;
  final String message;
  const CustomAuthException(this.code, this.message);

  @override
  String toString() => 'CustomAuthException($code): $message';
}
