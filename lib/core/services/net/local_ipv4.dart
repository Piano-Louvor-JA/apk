library;

import 'dart:io';

/// Escolhe o IPv4 do aparelho na rede — QUALQUER faixa (sem limitar a
/// 192.168.x): igrejas/empresas usam 10.x, 172.x, faixas públicas ou
/// CGNAT. Só o loopback fica fora. Com várias interfaces, ordem de
/// preferência: mesma sub-rede da TV > 192.168 > 10 > 172.16-31 >
/// qualquer outra > link-local 169.254 (sem DHCP).
Future<String?> pickLocalIpv4({String? preferPrefix}) async {
  try {
    final interfaces = await NetworkInterface.list();
    return chooseLocalIpv4([
      for (final it in interfaces)
        for (final addr in it.addresses)
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback)
            addr.address,
    ], preferPrefix: preferPrefix);
  } catch (_) {
    return null;
  }
}

/// Regra pura (testável) da escolha acima.
String? chooseLocalIpv4(List<String> candidates, {String? preferPrefix}) {
  int rank(String ip) {
    if (preferPrefix != null && ip.startsWith('$preferPrefix.')) return 0;
    if (ip.startsWith('192.168.')) return 1;
    if (ip.startsWith('10.')) return 2;
    final parts = ip.split('.');
    final second = parts.length > 1 ? int.tryParse(parts[1]) ?? -1 : -1;
    if (ip.startsWith('172.') && second >= 16 && second <= 31) return 3;
    if (ip.startsWith('169.254.')) return 5;
    return 4;
  }

  final list = candidates.where((ip) => !ip.startsWith('127.')).toList()
    ..sort((a, b) => rank(a).compareTo(rank(b)));
  return list.isEmpty ? null : list.first;
}

/// Prefixo /24 do IP escolhido (descoberta SSDP/webOS na sub-rede).
Future<String?> localSubnetPrefix() async {
  final ip = await pickLocalIpv4();
  return ip?.split('.').take(3).join('.');
}
