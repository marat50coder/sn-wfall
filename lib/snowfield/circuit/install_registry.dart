import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../dossier/client_dossier.dart';
import '../dossier/veiled_slots.dart';
import 'wire_courier.dart';

// ============================================================
//  InstallRegistry — AppsFlyer install + deep-link collector
// ============================================================
//  Fuses three signals into the verdict body:
//    1. onInstallConversionData — install attribution payload
//    2. onDeepLinking             — UDL / OneLink deep-link click
//    3. onAppOpenAttribution      — returning-user attribution
//
//  Organic rescue: AppsFlyer occasionally reports `af_status:
//  Organic` on the first callback for genuinely paid installs
//  (SDK timing). When that happens we wait and re-query the GCD
//  endpoint. If GCD succeeds its payload wins; otherwise we keep
//  the Organic one (the safe branch — user lands in the game).
//
//  Short-circuit: no dev key means the SDK never boots; the
//  futures complete immediately with an empty map so QA can
//  smoke-test the game path.
// ============================================================

class InstallRegistry {
  InstallRegistry();

  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _installData;
  Map<String, dynamic>? _deepLinkData;
  Map<String, dynamic>? _reopenData;

  final Completer<Map<String, dynamic>> _installReady =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkReady = Completer<void>();

  bool _wired = false;

  Future<void> ignite() async {
    if (_wired) return;
    _wired = true;

    final String devKey = ClientDossier.attributionKey;
    if (devKey.isEmpty) {
      _finishInstall(<String, dynamic>{});
      _finishDeepLink();
      return;
    }

    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: ClientDossier.iosNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic raw) async {
      final Map<String, dynamic> body = _unroll(raw);
      final String? status = body['af_status']?.toString();
      if (status == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: ClientDossier.organicRescueDelaySec),
        );
        final Map<String, dynamic>? rescued = await _gcdRescue();
        _installData = rescued ?? body;
      } else {
        _installData = body;
      }
      _finishInstall(_installData ?? <String, dynamic>{});
    });

    sdk.onAppOpenAttribution((dynamic raw) {
      _reopenData = _unroll(raw);
    });

    sdk.onDeepLinking((DeepLinkResult result) {
      final Map<String, dynamic>? click = result.deepLink?.clickEvent;
      if (click != null) {
        _deepLinkData = Map<String, dynamic>.from(click);
      }
      _finishDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _finishInstall(<String, dynamic>{});
      _finishDeepLink();
    }
  }

  Future<void> settleWithin({int? installSeconds}) async {
    final int seconds =
        installSeconds ?? ClientDossier.firstInstallWaitSec;
    await Future.wait<void>(<Future<void>>[
      _installReady.future.timeout(
        Duration(seconds: seconds),
        onTimeout: () => <String, dynamic>{},
      ),
      _deepLinkReady.future.timeout(
        Duration(seconds: ClientDossier.deepLinkWaitSec),
        onTimeout: () {},
      ),
    ]);
  }

  Future<String?> appsFlyerId() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> compile({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    if (_installData != null) body.addAll(_installData!);
    _deepLinkData?.forEach((String k, dynamic v) =>
        body.putIfAbsent(k, () => v));
    _reopenData?.forEach((String k, dynamic v) =>
        body.putIfAbsent(k, () => v));

    body['af_id'] = await appsFlyerId() ?? '';
    body['bundle_id'] = ClientDossier.bundle;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = ClientDossier.storeTag;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String project = ClientDossier.messagingProject;
    if (project.isNotEmpty) {
      body['firebase_project_id'] = project;
    }

    assert(() {
      // ignore: avoid_print
      print('[PRISM.TRACKER] compiled ${jsonEncode(body)}');
      return true;
    }());

    return body;
  }

  Future<Map<String, dynamic>?> _gcdRescue() async {
    try {
      final String? deviceUid = await appsFlyerId();
      if (deviceUid == null) return null;
      final String appRef = Platform.isIOS
          ? ClientDossier.iosNumericId
          : ClientDossier.bundle;
      final String url = unmaskGcdCallUrl(appRef, deviceUid);
      if (url.isEmpty) return null;

      final dynamic response = await wireCourier.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${ClientDossier.attributionKey}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _finishInstall(Map<String, dynamic> data) {
    if (!_installReady.isCompleted) _installReady.complete(data);
  }

  void _finishDeepLink() {
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }

  static Map<String, dynamic> _unroll(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final dynamic inner = raw['payload'] ?? raw['data'] ?? raw;
    if (inner is Map) {
      return inner.map((dynamic k, dynamic v) =>
          MapEntry<String, dynamic>(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
