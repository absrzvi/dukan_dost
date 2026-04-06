import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customers/providers/customers_provider.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../services/reminder_service.dart';

/// Provider for [ReminderService].
final reminderServiceProvider = Provider<ReminderService>((ref) {
  final eventRepository = ref.watch(eventRepositoryProvider);
  final customersRepository = ref.watch(customersRepositoryProvider);
  return ReminderService(eventRepository, customersRepository);
});
