class ReportCategory {
  final String key;
  final String label;
  final List<ReportSubReason> subReasons;

  const ReportCategory({
    required this.key,
    required this.label,
    required this.subReasons,
  });
}

class ReportSubReason {
  final String key;
  final String label;

  const ReportSubReason({required this.key, required this.label});
}

class ReportCategories {
  static const List<ReportCategory> all = [
    ReportCategory(
      key: 'fake_profile',
      label: 'Fake Profile',
      subReasons: [
        ReportSubReason(key: 'fake_identity', label: 'Fake Identity'),
        ReportSubReason(key: 'misleading_information', label: 'Misleading Information'),
        ReportSubReason(key: 'impersonating_someone', label: 'Impersonating Someone'),
      ],
    ),
    ReportCategory(
      key: 'scam_fraud',
      label: 'Scam / Fraud',
      subReasons: [
        ReportSubReason(key: 'asking_money_outside_dolo', label: 'Asking Money Outside Dolo'),
        ReportSubReason(key: 'payment_fraud', label: 'Payment Fraud'),
        ReportSubReason(key: 'suspicious_transaction_behavior', label: 'Suspicious Transaction Behaviour'),
      ],
    ),
    ReportCategory(
      key: 'inappropriate_behaviour',
      label: 'Inappropriate Behaviour',
      subReasons: [
        ReportSubReason(key: 'abusive_language', label: 'Abusive Language'),
        ReportSubReason(key: 'harassment', label: 'Harassment'),
        ReportSubReason(key: 'threatening_behavior', label: 'Threatening Behavior'),
      ],
    ),
    ReportCategory(
      key: 'outside_platform',
      label: 'Outside Platform',
      subReasons: [
        ReportSubReason(key: 'asking_whatsapp', label: 'Asking to Move to WhatsApp'),
        ReportSubReason(key: 'avoiding_dolo_system', label: 'Avoiding Dolo System'),
        ReportSubReason(key: 'bypass_platform_protections', label: 'Bypass Platform Protections'),
      ],
    ),
    ReportCategory(
      key: 'spam_misuse',
      label: 'Spam / Misuse',
      subReasons: [
        ReportSubReason(key: 'fake_orders', label: 'Fake Orders'),
        ReportSubReason(key: 'repeated_cancellations', label: 'Repeated Cancellations'),
        ReportSubReason(key: 'misusing_app', label: 'Misusing App'),
      ],
    ),
    ReportCategory(
      key: 'safety_concern',
      label: 'Safety Concern',
      subReasons: [
        ReportSubReason(key: 'person_went_missing', label: 'Person Went Missing'),
        ReportSubReason(key: 'theft', label: 'Theft'),
      ],
    ),
    ReportCategory(
      key: 'illegal_item',
      label: 'Illegal Item',
      subReasons: [
        ReportSubReason(key: 'suspicious_package', label: 'Suspicious Package'),
        ReportSubReason(key: 'restricted_goods', label: 'Restricted Goods'),
        ReportSubReason(key: 'illegal_item_transport', label: 'Illegal Item Transport'),
      ],
    ),
  ];

  static ReportCategory? findByKey(String key) {
    try {
      return all.firstWhere((c) => c.key == key);
    } catch (_) {
      return null;
    }
  }
}

class ReportModel {
  final String id;
  final String reporterUserId;
  final String reportedUserId;
  final String? orderId;
  final String category;
  final String subReason;
  final String? description;
  final String? attachmentUrl;
  final DateTime createdAt;

  ReportModel({
    required this.id,
    required this.reporterUserId,
    required this.reportedUserId,
    this.orderId,
    required this.category,
    required this.subReason,
    this.description,
    this.attachmentUrl,
    required this.createdAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id']?.toString() ?? '',
      reporterUserId: json['reporterUserId']?.toString() ?? '',
      reportedUserId: json['reportedUserId']?.toString() ?? '',
      orderId: json['orderId']?.toString(),
      category: json['category']?.toString() ?? '',
      subReason: json['sub_reason']?.toString() ?? '',
      description: json['description']?.toString(),
      attachmentUrl: json['attachment']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}