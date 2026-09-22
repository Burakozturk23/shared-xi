import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_xi/services/ads_consent_service.dart';

class FakeConsentInformation extends ConsentInformation {
  int updates = 0;
  bool allowed = false;
  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    OnConsentInfoUpdateSuccessListener successListener,
    OnConsentInfoUpdateFailureListener failureListener,
  ) {
    updates++;
    if (updates == 1) {
      failureListener(FormError(errorCode: 2, message: 'Network unavailable'));
    } else {
      successListener();
    }
  }

  @override
  Future<bool> canRequestAds() async => allowed;
  @override
  Future<bool> isConsentFormAvailable() async => true;
  @override
  Future<ConsentStatus> getConsentStatus() async => ConsentStatus.required;
  @override
  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async =>
      PrivacyOptionsRequirementStatus.required;
  @override
  Future<void> reset() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'consent retries a failed launch update and obeys SDK permission after forms',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final previous = ConsentInformation.instance;
      final consent = FakeConsentInformation();
      ConsentInformation.instance = consent;
      const channel = MethodChannel('plugins.flutter.io/google_mobile_ads/ump');
      final calls = <String>[];
      var failPrivacyForm = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (failPrivacyForm) throw PlatformException(code: '2');
            return null;
          });
      addTearDown(() {
        ConsentInformation.instance = previous;
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      await AdsConsentService.refresh();
      expect(consent.updates, 1);
      expect(calls, isEmpty); // Launch update does not present a form.
      expect(await AdsConsentService.ensureCanRequestAds(), isFalse);
      expect(
        consent.updates,
        2,
      ); // Network failure did not lock the entire session.
      expect(
        calls.single,
        'UserMessagingPlatform#loadAndShowConsentFormIfRequired',
      );
      expect(AdsConsentService.privacyOptionsRequired.value, isTrue);

      consent.allowed = true;
      expect(await AdsConsentService.ensureCanRequestAds(), isTrue);
      expect(
        consent.updates,
        2,
      ); // Successful update is reused during this launch.
      await AdsConsentService.showPrivacyOptions();
      expect(calls.last, 'UserMessagingPlatform#showPrivacyOptionsForm');
      failPrivacyForm = true;
      await expectLater(
        AdsConsentService.showPrivacyOptions(),
        throwsStateError,
      );
    },
  );
}
