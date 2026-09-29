/// Estrofe (slide) de música custom com timing — editor v3.1.
class CustomLyricSlide {
  final int id;
  final String text;
  final String? auxText;

  /// Tempo no formato do DB/.slja: 'MM:SS.mmm' ou 'HH:MM:SS.mmm'.
  final String? time;
  final int order;

  const CustomLyricSlide({
    required this.id,
    required this.text,
    this.auxText,
    this.time,
    required this.order,
  });

  factory CustomLyricSlide.fromJson(Map<String, dynamic> json) =>
      CustomLyricSlide(
        id: (json['id_lyric'] as num?)?.toInt() ?? 0,
        text: (json['lyric'] as String?) ?? '',
        auxText: json['aux_lyric'] as String?,
        time: json['time'] as String?,
        order: (json['order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id_lyric': id,
    'lyric': text,
    if (auxText != null) 'aux_lyric': auxText,
    if (time != null) 'time': time,
    'order': order,
  };

  /// Divide o texto colado em estrofes: bloco separado por linha vazia
  /// = 1 slide (mesma regra do desktop/web).
  static List<String> splitIntoSlides(String raw) => raw
      .split(RegExp(r'\n\s*\n'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

/// BG efetivo do slide [i]: o próprio, se escolhido; senão herda o do
/// slide 0 (padrão da música); slides com BG individual são exceção.
/// [backgrounds] mapeia índice do slide → caminho/id do BG escolhido.
T? effectiveSlideBg<T>(Map<int, T> backgrounds, int i) {
  if (backgrounds.containsKey(i)) return backgrounds[i];
  if (i > 0 && backgrounds.containsKey(0)) return backgrounds[0];
  return null;
}

/// Milissegundos → formato de tempo do DB/.slja: 'MM:SS.mmm'.
String msToDbTime(int ms) {
  final mm = (ms ~/ 60000).toString().padLeft(2, '0');
  final ss = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
  final mmm = (ms % 1000).toString().padLeft(3, '0');
  return '$mm:$ss.$mmm';
}
