import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/providers/transactions_provider.dart';
import '../services/reminder_service.dart';

/// Provider for [ReminderService].
final reminderServiceProvider = Provider<ReminderService>((ref) {
  final eventRepository = ref.watch(eventRepositoryProvider);
  return ReminderService(eventRepository);
});
