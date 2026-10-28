import 'cloud_models.dart';

class CloudClient {
  Future<CloudAccount> account() async => const CloudAccount(available: false);
  Future<void> requestLink(String email) =>
      throw const CloudFailure('not_configured');
  Future<void> signOut() => throw const CloudFailure('not_configured');
  Future<void> deleteAccount() => throw const CloudFailure('not_configured');
  Future<CloudAccount> save(String snapshot, int revision) =>
      throw const CloudFailure('not_configured');
  Future<String> download() => throw const CloudFailure('not_configured');
}
