class RemoteSabbathMarker {
  const RemoteSabbathMarker({
    required this.id,
    required this.offsetMs,
    required this.preset,
  });
  final String id, preset;
  final int offsetMs;
  Map<String, dynamic> toJson() => {
    'id': id,
    'offsetMs': offsetMs,
    'preset': preset,
  };
}

class RemoteSabbathPreset {
  const RemoteSabbathPreset({required this.id, this.name = ''});
  final String id, name;
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// Somente o estado do desktop: contagem, avisos e vídeo não rodam no APK.
class RemoteSabbathState {
  const RemoteSabbathState({
    this.status = 'idle',
    this.remainingMs = 2700000,
    this.durationMs = 2700000,
    this.finished = false,
    this.isProjecting = false,
    this.rehearsing = false,
    this.canStart = false,
    this.scheduleMode = 'duration',
    this.scheduleDurationMs = 2700000,
    this.endTime = '10:15',
    this.minDurationMs = 0,
    this.videoName,
    this.videoDurationMs = 0,
    this.videoActive = false,
    this.videoVolume = 100,
    this.videoMuted = false,
    this.audioLang = 'auto',
    this.audioVolume = 100,
    this.audioMuted = false,
    this.openingPlayback = 'stopped',
    this.hasOpening = false,
    this.markers = const [],
    this.presets = const [],
  });
  final String status, scheduleMode, endTime, audioLang, openingPlayback;
  final int remainingMs,
      durationMs,
      scheduleDurationMs,
      minDurationMs,
      videoDurationMs,
      audioVolume,
      videoVolume;
  final bool finished,
      isProjecting,
      rehearsing,
      canStart,
      videoActive,
      videoMuted,
      audioMuted,
      hasOpening;
  final String? videoName;
  final List<RemoteSabbathMarker> markers;
  final List<RemoteSabbathPreset> presets;
  bool get running => status == 'running';
  bool get idle => status == 'idle';
  Map<String, dynamic> toJson() => {
    'status': status,
    'remainingMs': remainingMs,
    'durationMs': durationMs,
    'finished': finished,
    'isProjecting': isProjecting,
    'rehearsing': rehearsing,
    'canStart': canStart,
    'schedule': {
      'scheduleMode': scheduleMode,
      'durationMs': scheduleDurationMs,
      'endTime': endTime,
    },
    'minDurationMs': minDurationMs,
    'videoName': videoName,
    'videoDurationMs': videoDurationMs,
    'videoActive': videoActive,
    'videoVolume': videoVolume,
    'videoMuted': videoMuted,
    'audioLang': audioLang,
    'audioVolume': audioVolume,
    'audioMuted': audioMuted,
    'openingPlayback': openingPlayback,
    'hasOpening': hasOpening,
    'markers': markers.map((m) => m.toJson()).toList(),
    'presets': presets.map((p) => p.toJson()).toList(),
  };
  static RemoteSabbathState? parse(Object? raw) {
    if (raw is! Map) return null;
    try {
      final schedule = raw['schedule'] is Map
          ? raw['schedule'] as Map
          : const {};
      int number(String key, [int fallback = 0]) =>
          (raw[key] as num?)?.toInt() ?? fallback;
      return RemoteSabbathState(
        status: raw['status'] as String? ?? 'idle',
        remainingMs: number('remainingMs'),
        durationMs: number('durationMs'),
        finished: raw['finished'] == true,
        isProjecting: raw['isProjecting'] == true,
        rehearsing: raw['rehearsing'] == true,
        canStart: raw['canStart'] == true,
        scheduleMode: schedule['scheduleMode'] as String? ?? 'duration',
        scheduleDurationMs:
            (schedule['durationMs'] as num?)?.toInt() ?? 2700000,
        endTime: schedule['endTime'] as String? ?? '10:15',
        minDurationMs: number('minDurationMs'),
        videoName: raw['videoName'] as String?,
        videoDurationMs: number('videoDurationMs'),
        videoActive: raw['videoActive'] == true,
        videoVolume: number('videoVolume', 100).clamp(0, 100),
        videoMuted: raw['videoMuted'] == true,
        audioLang: raw['audioLang'] as String? ?? 'auto',
        audioVolume: number('audioVolume', 100).clamp(0, 100),
        audioMuted: raw['audioMuted'] == true,
        openingPlayback: raw['openingPlayback'] as String? ?? 'stopped',
        hasOpening: raw['hasOpening'] == true,
        markers: (raw['markers'] as List? ?? [])
            .whereType<Map>()
            .where(
              (m) =>
                  m['id'] is String &&
                  m['preset'] is String &&
                  m['offsetMs'] is num,
            )
            .map(
              (m) => RemoteSabbathMarker(
                id: m['id'] as String,
                offsetMs: (m['offsetMs'] as num).toInt(),
                preset: m['preset'] as String,
              ),
            )
            .toList(),
        presets: (raw['presets'] as List? ?? [])
            .whereType<Map>()
            .where((p) => p['id'] is String)
            .map(
              (p) => RemoteSabbathPreset(
                id: p['id'] as String,
                name: p['name'] as String? ?? '',
              ),
            )
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }
}
