class CloudAccount {
  const CloudAccount({
    required this.available,
    this.email,
    this.revision = 0,
    this.updatedAt,
  });
  final bool available;
  final String? email;
  final int revision;
  final DateTime? updatedAt;

  factory CloudAccount.fromJson(Map<String, dynamic> value) => CloudAccount(
    available: value['available'] == true,
    email: value['email'] as String?,
    revision: value['revision'] as int? ?? 0,
    updatedAt: value['updatedAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (value['updatedAt'] as int) * 1000,
          ),
  );
}

class CloudFailure implements Exception {
  const CloudFailure(this.code);
  final String code;
}
