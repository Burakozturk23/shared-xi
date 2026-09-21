import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Consent refresh is silent on launch; forms appear only after an ad opt-in.
class AdsConsentService {
  AdsConsentService._();
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  static final privacyOptionsRequired = ValueNotifier<bool>(false);
  static Future<void>? _refresh;
  static Future<void>? _form;
  static Future<void> refresh() => _refresh ??= _update().then((success) {
    if (!success) {
      _refresh = null; // A later opt-in may retry a network failure.
    }
  });
  static Future<bool> _update() async {
    if (!supported) return true;
    final done = Completer<bool>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          if (!done.isCompleted) done.complete(true);
        },
        (_) {
          if (!done.isCompleted) done.complete(false);
        },
      );
      final success = await done.future.timeout(const Duration(seconds: 15));
      await _updatePrivacyEntry();
      return success;
    } catch (_) {
      // canRequestAds remains the authority; no consent strings are cached here.
      return false;
    }
  }

  static Future<void> _updatePrivacyEntry() async {
    privacyOptionsRequired.value =
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }

  static Future<bool> ensureCanRequestAds() async {
    if (!supported) return false;
    await refresh();
    _form ??= _showIfRequired();
    try {
      await _form;
    } finally {
      _form = null;
    }
    return ConsentInformation.instance.canRequestAds();
  }

  static Future<void> _showIfRequired() async {
    await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
    await _updatePrivacyEntry();
  }

  static Future<void> showPrivacyOptions() async {
    await refresh();
    if (!privacyOptionsRequired.value) return;
    FormError? formError;
    await ConsentForm.showPrivacyOptionsForm((error) => formError = error);
    if (formError != null) {
      throw StateError('Gizlilik tercihleri açılamadı. Tekrar dene.');
    }
    await _updatePrivacyEntry();
  }
}
