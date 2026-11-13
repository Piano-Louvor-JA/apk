/// Fundos do catálogo podem vir como URL absoluta, caminho relativo ou asset.
abstract final class MediaImageUrl {
  static String resolve(String raw, String filesBase) {
    final uri = Uri.tryParse(raw);
    if (raw.startsWith('asset:') ||
        uri?.scheme == 'http' ||
        uri?.scheme == 'https')
      return raw;
    final base = Uri.parse('${filesBase.replaceFirst(RegExp(r'/+$'), '')}/');
    if (raw.startsWith('//')) return '${base.scheme}:$raw';
    return base.resolve(raw.replaceFirst(RegExp(r'^/+'), '')).toString();
  }
}
