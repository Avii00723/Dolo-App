class SupportTicket {
  final String id;
  final String issueType;
  final String orderId;
  final String status; // 'open' | 'closed' | 'submitted'
  final DateTime createdAt;
  final List<SupportMessage> messages;

  const SupportTicket({
    required this.id,
    required this.issueType,
    required this.orderId,
    required this.status,
    required this.createdAt,
    required this.messages,
  });
}

class SupportMessage {
  final String text;
  final bool isUser; // true = sent by user, false = support agent
  final DateTime time;

  const SupportMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

// ── Hardcoded sample data ──
final List<SupportTicket> hardcodedTickets = [
  SupportTicket(
    id: 'TKT-001',
    issueType: 'Late Delivery',
    orderId: 'ORD-4821',
    status: 'open',
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    messages: [
      SupportMessage(
        text: 'My order #ORD-4821 has not arrived yet. It was supposed to be delivered yesterday.',
        isUser: true,
        time: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      SupportMessage(
        text: 'Hi! We are sorry for the inconvenience. We are looking into this right away. Could you share the traveller name?',
        isUser: false,
        time: DateTime.now().subtract(const Duration(hours: 2, minutes: 45)),
      ),
      SupportMessage(
        text: 'The traveller name is Rahul Sharma.',
        isUser: true,
        time: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
      ),
      SupportMessage(
        text: 'Thank you. We have flagged this to the traveller and will update you within 2 hours.',
        isUser: false,
        time: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ],
  ),
  SupportTicket(
    id: 'TKT-002',
    issueType: 'Wrong Item Received',
    orderId: 'ORD-3910',
    status: 'closed',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    messages: [
      SupportMessage(
        text: 'I received a wrong item in my order #ORD-3910.',
        isUser: true,
        time: DateTime.now().subtract(const Duration(days: 3)),
      ),
      SupportMessage(
        text: 'We sincerely apologise. A replacement has been initiated. Please allow 24-48 hours.',
        isUser: false,
        time: DateTime.now().subtract(const Duration(days: 2, hours: 22)),
      ),
    ],
  ),
];

const List<String> faqItemsData = [
  'I want to contact the seller/traveller',
  'How do I track my package?',
  'What happens if my delivery is delayed?',
  'How do I cancel an order?',
  'I want to report a damaged item',
];
