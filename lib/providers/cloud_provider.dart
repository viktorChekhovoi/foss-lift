import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cloud_client.dart';
import '../services/cloud_models.dart';

final cloudClientProvider = Provider<CloudClient>((ref) => CloudClient());
final cloudAccountProvider = FutureProvider<CloudAccount>(
  (ref) => ref.watch(cloudClientProvider).account(),
);
