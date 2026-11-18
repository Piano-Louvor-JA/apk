import 'package:flutter/foundation.dart';

/// Quais players completos estão visíveis na aba/rota atual.
class RemotePlayerPresence extends ValueNotifier<bool> {
  RemotePlayerPresence() : super(false);
  final Set<Object> _owners = {};

  void update(Object owner, bool visible) {
    if (visible) {
      _owners.add(owner);
    } else {
      _owners.remove(owner);
    }
    value = _owners.isNotEmpty;
  }
}

final remotePlayerPresence = RemotePlayerPresence();

final remoteBiblePresence = RemotePlayerPresence();
final remoteBibleMinimized = ValueNotifier<bool>(false);
