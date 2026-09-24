import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/community_models.dart';
import 'package:shared_xi/models/friend_models.dart';
import 'package:shared_xi/models/leaderboard_models.dart';
import 'package:shared_xi/models/safety_models.dart';
import 'package:shared_xi/screens/community_center_page.dart';
import 'package:shared_xi/screens/friends_page.dart';
import 'package:shared_xi/screens/leaderboard_page.dart';
import 'package:shared_xi/screens/social_safety_center_page.dart';
import 'package:shared_xi/services/social/social_gateways.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';

CommunityRequest request({
  String subject = 'Yeni bir önerim var',
  String message = 'Mesajın tamamı burada.',
}) => CommunityRequest(
  submissionId: 'request-1',
  category: CommunityRequestCategory.suggestion,
  subject: subject,
  message: message,
  contextTag: '',
  modeId: '',
  status: CommunityRequestStatus.reviewing,
  createdAt: 1790164800000,
  updatedAt: 1790164800000,
);

class CommunityFake extends CommunityGateway {
  bool failSubmit = false, failHistory = false;
  int submissions = 0;
  List<CommunityRequest> rows = [];
  Completer<CommunitySubmitResult>? pending;
  @override
  bool get isGoogleAccount => true;
  @override
  Future<void> prepare() async {}
  @override
  Future<List<CommunityRequest>> listMine() async {
    if (failHistory) throw StateError('offline');
    return rows;
  }

  @override
  Future<CommunitySubmitResult> submit({
    required CommunityRequestCategory category,
    required String subject,
    required String message,
    String modeId = '',
  }) async {
    submissions++;
    if (failSubmit) throw StateError('offline');
    if (pending != null) return pending!.future;
    return CommunitySubmitResult(
      submission: request(subject: subject, message: message),
    );
  }
}

class FriendsFake extends FriendsGateway {
  bool google = true, failFriends = false;
  int preparations = 0, friendStreams = 0, searches = 0, sends = 0, removes = 0;
  List<FriendshipEdge> rows = [];
  @override
  bool get isGoogleAccount => google;
  @override
  Future<void> prepare() async {
    preparations++;
  }

  @override
  Stream<List<FriendshipEdge>> friends() {
    friendStreams++;
    return failFriends
        ? Stream.error(StateError('permission-denied: internal path'))
        : Stream.value(rows);
  }

  @override
  Stream<List<FriendRequestEdge>> incoming() => Stream.value([]);
  @override
  Stream<List<FriendRequestEdge>> outgoing() => Stream.value([]);
  @override
  Stream<List<BlockedUserEdge>> blocks() => Stream.value([]);
  @override
  Stream<List<FriendMatchInvite>> invites() => Stream.value([]);
  @override
  Future<PublicFriendProfile?> profile(String uid) async => PublicFriendProfile(
    uid: uid,
    displayName: 'Saha Kaptanı',
    normalizedName: 'saha_kaptani',
    avatarId: 'starter_ball',
    elo: 1240,
  );
  @override
  Future<FriendSearchResult> search(String name) async {
    searches++;
    return FriendSearchResult(
      found: true,
      profile: await profile('friend-1'),
      relationship: FriendRelationship.none,
    );
  }

  @override
  Future<FriendRelationship> sendRequest(String uid) async {
    sends++;
    return FriendRelationship.outgoingPending;
  }

  @override
  Future<FriendRelationship> removeFriend(String uid) async {
    removes++;
    return FriendRelationship.none;
  }
}

class SafetyFake extends SafetyGateway {
  bool fail = false, google = true;
  @override
  bool get isGoogleAccount => google;
  @override
  Future<List<PlayerReportSummary>> listMine() async {
    if (fail) throw StateError('offline');
    // Production returns an unmodifiable list; UI must not sort it in place.
    return List.unmodifiable([
      const PlayerReportSummary(
        reportId: 'report-1',
        targetUid: 'friend-1',
        targetDisplayName: 'Saha Kaptanı',
        targetAvatarId: 'starter_ball',
        category: PlayerReportCategory.spam,
        sourceContext: 'friends',
        modeId: null,
        status: PlayerReportStatus.reviewing,
        createdAtMs: 1790164800000,
        updatedAtMs: 1790164800000,
      ),
    ]);
  }
}

class BoardFake extends LeaderboardGateway {
  bool fail = false;
  int subscriptions = 0;
  @override
  String? get uid => 'outside-top-100';
  @override
  Future<void> prepare() async {}
  @override
  Stream<LeaderboardSnapshot> watch(LeaderboardScope scope, DateTime date) {
    subscriptions++;
    return fail
        ? Stream.error(StateError('secret_backend_path'))
        : Stream.value(
            LeaderboardSnapshot(
              scope: scope,
              periodKey: scope == LeaderboardScope.daily
                  ? '2026-09-23'
                  : '2026-W39',
              availability: LeaderboardAvailability.available,
              serverValidated: true,
              entries: List.generate(
                5,
                (i) => LeaderboardEntry(
                  rank: i + 1,
                  uid: 'player-$i',
                  displayName: [
                    'Saha Kaptanı',
                    'Son Dakika',
                    'Pas Ustası',
                    'Golcü',
                    'Kaleci',
                  ][i],
                  value: 1540 - i * 90,
                ),
              ),
            ),
          );
  }
}

Future<GlobalKey> open(
  WidgetTester tester,
  Widget page, {
  bool dark = true,
  double scale = 1,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? OrtakSahaTheme.dark : OrtakSahaTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(key: key, child: page),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first,
    maxScrolls: 30,
  );
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/social_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, path) in [
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });
  testWidgets(
    'single-subscription feeds survive repeated tab changes and refresh',
    (tester) async {
      final fake = FriendsFake();
      await open(tester, FriendsPage(gateway: fake));
      for (var cycle = 0; cycle < 3; cycle++) {
        for (final label in ['İstekler', 'Arkadaş Ara', 'Arkadaşlarım']) {
          await tester.tap(find.text(label).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
      expect(fake.friendStreams, 1);
      await tester.tap(find.byTooltip('Yenile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İstekler'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(fake.friendStreams, 2);
    },
  );
  testWidgets(
    'failed community submission keeps the draft; duplicate taps submit once',
    (tester) async {
      final fake = CommunityFake()..failSubmit = true;
      await open(tester, CommunityCenterPage(gateway: fake));
      final subject = find.byKey(const ValueKey('community-subject'));
      final message = find.byKey(const ValueKey('community-message'));
      await reveal(tester, subject);
      await tester.enterText(subject, 'Daha fazla görev');
      await reveal(tester, message);
      await tester.enterText(
        message,
        'Haftalık yeni görevler görmek istiyorum.',
      );
      tester.testTextInput.hide();
      await reveal(tester, find.text('Talebi gönder'));
      await tester.tap(find.text('Talebi gönder'));
      await tester.pumpAndSettle();
      expect(fake.submissions, 1);
      expect(
        tester.widget<TextFormField>(message).controller!.text,
        'Haftalık yeni görevler görmek istiyorum.',
      );
      fake.failSubmit = false;
      fake.failHistory = true;
      fake.pending = Completer<CommunitySubmitResult>();
      await tester.tap(find.text('Talebi gönder'));
      await tester.pump();
      expect(find.text('Gönderiliyor…'), findsOneWidget);
      expect(fake.submissions, 2);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Gönderiliyor…'),
      );
      expect(button.onPressed, isNull);
      fake.pending!.complete(
        CommunitySubmitResult(
          submission: request(subject: 'Daha fazla görev', message: ''),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Daha fazla görev'));
      await tester.tap(find.text('Daha fazla görev'));
      await tester.pumpAndSettle();
      expect(
        find.text('Haftalık yeni görevler görmek istiyorum.'),
        findsWidgets,
      );
      expect(find.text('Talep no: request-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'friend stream failure offers retry and does not leak backend details',
    (tester) async {
      final fake = FriendsFake()..failFriends = true;
      await open(tester, FriendsPage(gateway: fake));
      expect(find.text('Liste yüklenemedi'), findsOneWidget);
      expect(find.textContaining('internal path'), findsNothing);
      fake.failFriends = false;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(find.text('İlk arkadaşını ekle'), findsOneWidget);
      expect(fake.preparations, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'friend search sends a request once and updates its relationship',
    (tester) async {
      final fake = FriendsFake();
      await open(tester, FriendsPage(gateway: fake, initialTab: 2));
      final input = find.byType(TextField);
      await reveal(tester, input);
      await tester.enterText(input, 'saha_kaptani');
      tester.testTextInput.hide();
      await reveal(tester, find.widgetWithText(FilledButton, 'Arkadaş Ara'));
      await tester.tap(find.widgetWithText(FilledButton, 'Arkadaş Ara'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Arkadaş Ekle'));
      await tester.tap(find.text('Arkadaş Ekle'));
      await tester.pumpAndSettle();
      expect(fake.searches, 1);
      expect(fake.sends, 1);
      expect(find.text('İsteği İptal Et'), findsOneWidget);
      expect(fake.friendStreams, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'friend removal requires confirmation and cancel does not mutate',
    (tester) async {
      final fake = FriendsFake()
        ..rows = [const FriendshipEdge(uid: 'friend-1')];
      await open(tester, FriendsPage(gateway: fake));
      await tester.tap(find.byTooltip('Arkadaş seçenekleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arkadaşlıktan çıkar'));
      await tester.pumpAndSettle();
      expect(fake.removes, 0);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(fake.removes, 0);
      expect(fake.friendStreams, 1);
    },
  );
  testWidgets(
    'guest friends page offers account connection without server reads',
    (tester) async {
      final fake = FriendsFake()..google = false;
      await open(tester, FriendsPage(gateway: fake));
      expect(find.text('Google hesabını bağla'), findsOneWidget);
      expect(fake.preparations, 0);
      expect(fake.friendStreams, 0);
    },
  );
  testWidgets(
    'leaderboard retry uses trusted stream and explains the top-100 limit',
    (tester) async {
      final fake = BoardFake()..fail = true;
      await open(tester, LeaderboardPage(gateway: fake));
      expect(find.text('Sıralama yenilenemedi'), findsOneWidget);
      expect(find.textContaining('secret_backend_path'), findsNothing);
      fake.fail = false;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Gösterilen ilk 100'), findsOneWidget);
      expect(fake.subscriptions, 4);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('report history handles immutable data, filtering and detail', (
    tester,
  ) async {
    await open(tester, SocialSafetyCenterPage(gateway: SafetyFake()));
    await reveal(tester, find.text('Sonuçlanan'));
    await tester.tap(find.text('Sonuçlanan'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Bu filtrede rapor yok'));
    expect(find.text('Bu filtrede rapor yok'), findsOneWidget);
    await tester.tap(find.text('Tümü'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Saha Kaptanı'));
    await tester.tap(find.text('Saha Kaptanı'));
    await tester.pumpAndSettle();
    expect(find.text('Rapor no: report-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final dark in [true, false]) {
    for (final large in [false, true]) {
      testWidgets(
        'social pages fit ${large ? '320px large text' : '390px'} dark=$dark',
        (tester) async {
          final friends = FriendsFake()
            ..rows = [const FriendshipEdge(uid: 'friend-1')];
          for (final (name, page) in <(String, Widget)>[
            ('community', CommunityCenterPage(gateway: CommunityFake())),
            ('friends', FriendsPage(gateway: friends)),
            ('leaderboard', LeaderboardPage(gateway: BoardFake())),
            ('safety', SocialSafetyCenterPage(gateway: SafetyFake())),
          ]) {
            final key = await open(
              tester,
              page,
              dark: dark,
              scale: large ? 1.8 : 1,
              width: large ? 320 : 390,
            );
            expect(tester.takeException(), isNull, reason: '$name initial');
            await capture(
              tester,
              key,
              '$name-${dark ? 'dark' : 'light'}-${large ? 'large' : 'normal'}',
            );
            final scroll = find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .first;
            await tester.drag(scroll, const Offset(0, -1400));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$name scrolled');
          }
        },
      );
    }
  }
}
