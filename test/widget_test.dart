import 'package:flutter_test/flutter_test.dart';
import 'package:arofi_support/src/models/support_models.dart';

void main() {
  test('support ticket parses live chat payloads', () {
    final ticket = SupportTicket.fromJson({
      'id': 't1',
      'reference': 'CHAT-1',
      'subject': 'Live chat with Customer',
      'category': 'Live Chat',
      'priority': 'NORMAL',
      'status': 'OPEN',
      'channel': 'CHAT',
      'createdAt': '2026-09-06T10:00:00Z',
      'messages': [
        {
          'id': 'm1',
          'authorName': 'Customer',
          'authorRole': 'CUSTOMER',
          'body': 'Hello',
          'isInternal': false,
          'createdAt': '2026-09-06T10:01:00Z',
          'attachments': [],
        }
      ],
    });
    expect(ticket.isLiveChat, isTrue);
    expect(ticket.isOpen, isTrue);
    expect(ticket.lastMessage?.body, 'Hello');
    expect(ticket.lastMessage?.fromCustomer, isTrue);
  });
}
