enum CommunityRequestCategory {
  suggestion,
  bugReport,
  help,
  matchmakingIssue,
  feedback,
}

extension CommunityRequestCategoryWire on CommunityRequestCategory {
  String get wireValue {
    switch (this) {
      case CommunityRequestCategory.suggestion:
        return 'suggestion';
      case CommunityRequestCategory.bugReport:
        return 'bug_report';
      case CommunityRequestCategory.help:
        return 'help';
      case CommunityRequestCategory.matchmakingIssue:
        return 'matchmaking_issue';
      case CommunityRequestCategory.feedback:
        return 'feedback';
    }
  }

  String get label {
    switch (this) {
      case CommunityRequestCategory.suggestion:
        return 'Öneri';
      case CommunityRequestCategory.bugReport:
        return 'Hata bildir';
      case CommunityRequestCategory.help:
        return 'Yardım';
      case CommunityRequestCategory.matchmakingIssue:
        return 'Eşleşme sorunu';
      case CommunityRequestCategory.feedback:
        return 'Genel geri bildirim';
    }
  }

  static CommunityRequestCategory fromWire(String value) {
    switch (value) {
      case 'bug_report':
        return CommunityRequestCategory.bugReport;
      case 'help':
        return CommunityRequestCategory.help;
      case 'matchmaking_issue':
        return CommunityRequestCategory.matchmakingIssue;
      case 'feedback':
        return CommunityRequestCategory.feedback;
      case 'suggestion':
      default:
        return CommunityRequestCategory.suggestion;
    }
  }
}

enum CommunityRequestStatus {
  open,
  reviewing,
  resolved,
  closed,
}

extension CommunityRequestStatusWire on CommunityRequestStatus {
  String get wireValue => name;

  String get label {
    switch (this) {
      case CommunityRequestStatus.open:
        return 'Alındı';
      case CommunityRequestStatus.reviewing:
        return 'İnceleniyor';
      case CommunityRequestStatus.resolved:
        return 'Çözüldü';
      case CommunityRequestStatus.closed:
        return 'Kapatıldı';
    }
  }

  static CommunityRequestStatus fromWire(String value) {
    switch (value) {
      case 'reviewing':
        return CommunityRequestStatus.reviewing;
      case 'resolved':
        return CommunityRequestStatus.resolved;
      case 'closed':
        return CommunityRequestStatus.closed;
      case 'open':
      default:
        return CommunityRequestStatus.open;
    }
  }
}

class CommunityRequest {
  final String submissionId;
  final CommunityRequestCategory category;
  final String subject;
  final String message;
  final String contextTag;
  final String modeId;
  final CommunityRequestStatus status;
  final int createdAt;
  final int updatedAt;

  const CommunityRequest({
    required this.submissionId,
    required this.category,
    required this.subject,
    required this.message,
    required this.contextTag,
    required this.modeId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommunityRequest.fromMap(Map<String, dynamic> map) {
    return CommunityRequest(
      submissionId: map['submissionId']?.toString() ?? '',
      category: CommunityRequestCategoryWire.fromWire(
        map['category']?.toString() ?? '',
      ),
      subject: map['subject']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      contextTag: map['contextTag']?.toString() ?? '',
      modeId: map['modeId']?.toString() ?? '',
      status: CommunityRequestStatusWire.fromWire(
        map['status']?.toString() ?? '',
      ),
      createdAt: _int(map['createdAt']),
      updatedAt: _int(map['updatedAt']),
    );
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class CommunitySubmitResult {
  final CommunityRequest submission;

  const CommunitySubmitResult({
    required this.submission,
  });
}
