/// The only outbound app transport: same-origin cloud backup, used on demand.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'cloud_models.dart';

class CloudClient {
  Future<String> _request(
    String path, {
    String method = 'GET',
    String? body,
    int? revision,
  }) async {
    final controller = web.AbortController();
    final timer = Timer(const Duration(seconds: 30), () => controller.abort());
    try {
      final response = await web.window
          .fetch(
            path.toJS,
            web.RequestInit(
              method: method,
              credentials: 'same-origin',
              cache: 'no-store',
              signal: controller.signal,
              headers:
                  {
                        if (body != null) 'Content-Type': 'application/json',
                        if (revision != null) 'If-Match': '"$revision"',
                      }.jsify()
                      as JSObject,
              body: body?.toJS,
            ),
          )
          .toDart;
      final text = (await response.text().toDart).toDart;
      if (!response.ok) {
        var code = 'service_unavailable';
        try {
          code = (jsonDecode(text) as Map)['error'] as String;
        } catch (_) {}
        throw CloudFailure(code);
      }
      return text;
    } on CloudFailure {
      rethrow;
    } catch (_) {
      throw const CloudFailure('service_unavailable');
    } finally {
      timer.cancel();
    }
  }

  Future<CloudAccount> account() async => CloudAccount.fromJson(
    jsonDecode(await _request('/api/session')) as Map<String, dynamic>,
  );
  Future<void> requestLink(String email) async {
    await _request(
      '/api/auth/request',
      method: 'POST',
      body: jsonEncode({'email': email}),
    );
  }

  Future<void> signOut() async {
    await _request('/api/auth/logout', method: 'POST');
  }

  Future<void> deleteAccount() async {
    await _request('/api/account', method: 'DELETE');
  }

  Future<CloudAccount> save(String snapshot, int revision) async {
    await _request(
      '/api/backup',
      method: 'PUT',
      body: snapshot,
      revision: revision,
    );
    return account();
  }

  Future<String> download() => _request('/api/backup');
}
