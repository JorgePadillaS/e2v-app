import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider to trigger wallet refresh from external events (tabs, lifecycle, etc.)
final walletRefreshProvider = StateProvider<int>((ref) => 0);
