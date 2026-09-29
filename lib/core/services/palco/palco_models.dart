library;

/// Mensagens do protocolo Palco v2 (WS JSON).
///
/// Contrato validado no spike ~/palco-spike (2026-08-17, LG UM7510):
/// sender→receiver: projection, audio, video, timer, bgPalco, idle, volume.
/// receiver→sender: unlocked, ended, status, error, remote-key.
///
/// Regra crítica: mídia SEMPRE via proxy do sender com IP da sub-rede da TV
/// (nunca localhost) — ver PalcoProxy.
class PalcoMessage {
  const PalcoMessage({
    required this.type,
    this.version = 2,
    this.fields = const {},
  });

  final int version;
  final String type;
  final Map<String, dynamic> fields;

  Map<String, dynamic> toJson() => {'v': version, 'type': type, ...fields};

  factory PalcoMessage.fromJson(Map<String, dynamic> json) {
    final v = json['v'];
    if (v != 1 && v != 2) {
      throw FormatException('Versão de protocolo Palco não suportada: $v');
    }
    final type = json['type'];
    if (type is! String || type.isEmpty) {
      throw const FormatException('Mensagem Palco sem type');
    }
    return PalcoMessage(
      version: v as int,
      type: type,
      fields: Map<String, dynamic>.from(json)
        ..remove('v')
        ..remove('type'),
    );
  }

  // ---- Fabricadores sender→receiver ----

  /// Projeta texto/BG. [text] aceita <br> (quebra de linha, innerHTML no receiver).
  /// F3.3m: [footerRef]/[footerColor]/[footerWeight]/[footerVersion] — footer
  /// com referência destacada + versão (Bíblia). [textShadow]/[shadowBlur]/
  /// [shadowIntensity]/[textBox]/[boxOpacity]/[boxBorder] — estilos da letra.
  static PalcoMessage projection({
    required String text,
    String footer = '',
    String? background,
    String? footerRef,
    String? footerColor,
    int? footerWeight,
    String? footerVersion,
    bool? textShadow,
    double? shadowBlur,
    double? shadowIntensity,
    bool? textBox,
    double? boxOpacity,
    Map<String, dynamic>? boxBorder,
    String? textAlign,
    String? textVerticalAlign,
    double? fontSize,
    int? fontWeight,
  }) => PalcoMessage(
    type: 'projection',
    fields: {
      'text': text,
      'footer': footer,
      if (background != null) 'background': background,
      if (footerRef != null) 'footerRef': footerRef,
      if (footerColor != null) 'footerColor': footerColor,
      if (footerWeight != null) 'footerWeight': footerWeight,
      if (footerVersion != null) 'footerVersion': footerVersion,
      if (textShadow != null) 'textShadow': textShadow,
      if (shadowBlur != null) 'shadowBlur': shadowBlur,
      if (shadowIntensity != null) 'shadowIntensity': shadowIntensity,
      if (textBox != null) 'textBox': textBox,
      if (boxOpacity != null) 'boxOpacity': boxOpacity,
      if (boxBorder != null) 'boxBorder': boxBorder,
      if (textAlign != null) 'textAlign': textAlign,
      if (textVerticalAlign != null) 'textVerticalAlign': textVerticalAlign,
      if (fontSize != null) 'fontSize': fontSize,
      if (fontWeight != null) 'fontWeight': fontWeight,
    },
  );

  /// Áudio com now-playing opcional. [positionMs] sincroniza a TV com a
  /// posição do player local (F3.3g — play de tela no meio da faixa não
  /// pode recomeçar do zero na TV).
  static PalcoMessage audio(
    String url, {
    String action = 'play',
    String? title,
    String? subtitle,
    String? cover,
    String? background,
    int? positionMs,
  }) => PalcoMessage(
    type: 'audio',
    fields: {
      'url': url,
      'action': action,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (cover != null) 'cover': cover,
      if (background != null) 'background': background,
      if (positionMs != null) 'positionMs': positionMs,
    },
  );

  static PalcoMessage video(String url, {String action = 'play'}) =>
      PalcoMessage(type: 'video', fields: {'url': url, 'action': action});

  static PalcoMessage timer({
    required String action,
    int duration = 0,
    String mode = 'countdown',
    String label = '',
    String? color,
    double? fontSize,
    int? fontWeight,
    bool? textShadow,
    double? shadowBlur,
    double? shadowIntensity,
    String? textAlign,
    String? textVerticalAlign,
  }) => PalcoMessage(
    type: 'timer',
    fields: {
      'action': action,
      'duration': duration,
      'mode': mode,
      'label': label,
      if (color != null) 'color': color,
      if (fontSize != null) 'fontSize': fontSize,
      if (fontWeight != null) 'fontWeight': fontWeight,
      if (textShadow != null) 'textShadow': textShadow,
      if (shadowBlur != null) 'shadowBlur': shadowBlur,
      if (shadowIntensity != null) 'shadowIntensity': shadowIntensity,
      if (textAlign != null) 'textAlign': textAlign,
      if (textVerticalAlign != null) 'textVerticalAlign': textVerticalAlign,
    },
  );

  static PalcoMessage bgPalco(String? url) =>
      PalcoMessage(type: 'bgPalco', fields: {'url': url ?? ''});

  static const PalcoMessage idleRequest = PalcoMessage(type: 'idle');

  // ---- Controle remoto (desktop/web receiver) ----

  /// remote.command: play|pause|stop|volume|seek enviado a um receiver
  /// com role 'desktop'/'web'. `id` correlaciona o ack.
  static PalcoMessage remoteCommand(
    String command, {
    String? id,
    double? value,
  }) => PalcoMessage(
    type: 'remote.command',
    fields: {
      'command': command,
      if (id != null) 'id': id,
      if (value != null) 'value': value,
    },
  );

  // ---- Accessors receiver→sender ----

  /// remote-key: setas/OK do controle da TV ('next' | 'prev').
  String? get remoteKey => fields['key'] as String?;

  /// ended: audio|video terminou.
  String? get endedMedia => fields['media'] as String?;

  /// hello: role do receiver ('tv' | 'desktop' | 'web').
  String? get helloRole => fields['role'] as String?;

  /// remote.ack: id do comando confirmado.
  String? get remoteAckId => fields['id'] as String?;

  /// remote.ack: sucesso do comando.
  bool get remoteAckOk => fields['ok'] == true;

  /// remote.state: snapshot do player do receiver (estado de playback).
  Map<String, dynamic> get remoteState =>
      Map<String, dynamic>.from(fields['state'] as Map? ?? const {});
}
