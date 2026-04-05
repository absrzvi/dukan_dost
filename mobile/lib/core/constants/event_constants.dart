/// Event type and party type constants.
/// Mirror the CHECK constraints in the Events Drift table and Django model.
class EventType {
  static const String credit = 'CREDIT';
  static const String payment = 'PAYMENT';
  static const String reversal = 'REVERSAL';
  static const String reminderSent = 'REMINDER_SENT';
}

class PartyType {
  static const String customer = 'CUSTOMER';
  static const String supplier = 'SUPPLIER';
}
