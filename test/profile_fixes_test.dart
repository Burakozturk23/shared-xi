import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/services/replay_stream.dart';
import 'package:shared_xi/services/nickname_service.dart';
import 'package:shared_xi/widgets/nickname_edit_dialog.dart';

Future<void> openEditor(
  WidgetTester t,
  Future<void> Function(String) save,
) async {
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) =>
                  NicknameEditDialog(initialName: 'Kaptan', save: save),
            ),
            child: const Text('Düzenle'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('Düzenle'));
  await t.pumpAndSettle();
}

void main() {
  test(
    'single upstream replays latest value and errors; disposal cancels source',
    () async {
      var cancellations = 0;
      final source = StreamController<int>(
        onCancel: () {
          cancellations++;
        },
      );
      final replay = ReplayStream(source.stream);
      final first = <int>[];
      final errors = <Object>[];
      final a = replay.stream.listen(first.add, onError: errors.add);
      source.add(1);
      await Future<void>.delayed(Duration.zero);
      await a.cancel();
      source.add(2);
      await Future<void>.delayed(Duration.zero);
      final second = <int>[];
      final b = replay.stream.listen(second.add, onError: errors.add);
      await Future<void>.delayed(Duration.zero);
      expect(second, [2]);
      source.addError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      await b.cancel();
      final c = replay.stream.listen((_) {}, onError: errors.add);
      await Future<void>.delayed(Duration.zero);
      expect(errors, hasLength(2));
      await replay.dispose();
      await c.cancel();
      await source.close();
      expect(cancellations, 1);
    },
  );
  testWidgets(
    'nickname success closes with keyboard active without disposed editor errors',
    (t) async {
      final pending = Completer<void>();
      var calls = 0;
      await openEditor(t, (_) {
        calls++;
        return pending.future;
      });
      await t.enterText(find.byType(TextField), 'Yeni_Kaptan');
      await t.tap(find.text('Kaydet'));
      await t.pump();
      expect(calls, 1);
      expect(
        t
            .widget<TextButton>(find.widgetWithText(TextButton, 'İptal'))
            .onPressed,
        isNull,
      );
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(NicknameEditDialog), findsOneWidget);
      pending.complete();
      await t.pumpAndSettle();
      expect(find.byType(NicknameEditDialog), findsNothing);
      expect(t.takeException(), isNull);
      await t.tap(find.text('Düzenle'));
      await t.pumpAndSettle();
      await t.tap(find.text('İptal'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'nickname failure stays editable and late completion after unmount is safe',
    (t) async {
      await openEditor(t, (_) async {
        throw const NicknameException(
          NicknameErrorCode.taken,
          'Bu ad alınmış.',
        );
      });
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();
      expect(find.text('Bu ad alınmış.'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      await t.tap(find.text('İptal'));
      await t.pumpAndSettle();
      final pending = Completer<void>();
      await openEditor(t, (_) => pending.future);
      await t.tap(find.text('Kaydet'));
      await t.pump();
      await t.pumpWidget(const SizedBox.shrink());
      pending.completeError(StateError('late failure'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
}
