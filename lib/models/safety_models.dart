enum PlayerReportCategory {
  harassment,
  hateSpeech,
  cheating,
  inappropriateName,
  spam,
  other,
}

extension PlayerReportCategoryWire on PlayerReportCategory {
  String get wire {
    switch (this) {
      case PlayerReportCategory.harassment:
        return 'harassment';
      case PlayerReportCategory.hateSpeech:
        return 'hate_speech';
      case PlayerReportCategory.cheating:
        return 'cheating';
      case PlayerReportCategory.inappropriateName:
        return 'inappropriate_name';
      case PlayerReportCategory.spam:
        return 'spam';
      case PlayerReportCategory.other:
        return 'other';
    }
  }

  String get title {
    switch (this) {
      case PlayerReportCategory.harassment:
        return 'Taciz / rahatsız etme';
      case PlayerReportCategory.hateSpeech:
        return 'Nefret söylemi';
      case PlayerReportCategory.cheating:
        return 'Hile şüphesi';
      case PlayerReportCategory.inappropriateName:
        return 'Uygunsuz takma ad';
      case PlayerReportCategory.spam:
        return 'Spam';
      case PlayerReportCategory.other:
        return 'Diğer';
    }
  }

  static PlayerReportCategory fromWire(String? value) {
    switch (value) {
      case 'harassment':
        return PlayerReportCategory.harassment;
      case 'hate_speech':
        return PlayerReportCategory.hateSpeech;
      case 'cheating':
        return PlayerReportCategory.cheating;
      case 'inappropriate_name':
        return PlayerReportCategory.inappropriateName;
      case 'spam':
        return PlayerReportCategory.spam;
      default:
        return PlayerReportCategory.other;
    }
  }
}

enum PlayerReportStatus { open, reviewing, actioned, closed }

extension PlayerReportStatusWire on PlayerReportStatus {
  String get title {
    switch (this) {
      case PlayerReportStatus.open:
        return 'Alındı';
      case PlayerReportStatus.reviewing:
        return 'İnceleniyor';
      case PlayerReportStatus.actioned:
        return 'İşlem uygulandı';
      case PlayerReportStatus.closed:
        return 'Kapatıldı';
    }
  }

  static PlayerReportStatus fromWire(String? value) {
    switch (value) {
      case 'reviewing':
        return PlayerReportStatus.reviewing;
      case 'actioned':
        return PlayerReportStatus.actioned;
      case 'closed':
        return PlayerReportStatus.closed;
      default:
        return PlayerReportStatus.open;
    }
  }
}

class PlayerReportSummary {
  final String reportId;
  final String targetUid;
  final String targetDisplayName;
  final String targetAvatarId;
  final PlayerReportCategory category;
  final String sourceContext;
  final String? modeId;
  final PlayerReportStatus status;
  final int? createdAtMs;
  final int? updatedAtMs;

  const PlayerReportSummary({
    required this.reportId,
    required this.targetUid,
    required this.targetDisplayName,
    required this.targetAvatarId,
    required this.category,
    required this.sourceContext,
    required this.modeId,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  factory PlayerReportSummary.fromMap(Map<String, dynamic> data) {
    return PlayerReportSummary(
      reportId: data['reportId']?.toString() ?? '',
      targetUid: data['targetUid']?.toString() ?? '',
      targetDisplayName: data['targetDisplayName']?.toString() ?? 'Oyuncu',
      targetAvatarId: data['targetAvatarId']?.toString() ?? 'starter_ball',
      category: PlayerReportCategoryWire.fromWire(data['category']?.toString()),
      sourceContext: data['sourceContext']?.toString() ?? 'other',
      modeId: _optionalString(data['modeId']),
      status: PlayerReportStatusWire.fromWire(data['status']?.toString()),
      createdAtMs: _toInt(data['createdAt']),
      updatedAtMs: _toInt(data['updatedAt']),
    );
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
