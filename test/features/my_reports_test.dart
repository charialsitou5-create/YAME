import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yame/core/constants/app_strings.dart';
import 'package:yame/features/support/my_reports_screen.dart';
import 'package:yame/models/my_report.dart';
import 'package:yame/repositories/incident_repository.dart';
import 'package:yame/repositories/user_repository.dart';

import '../support/fake_backend.dart';

MyReport _r(String id, int day) => MyReport(
      id: id,
      kind: 'incident',
      category: 'securite',
      message: 'msg $id',
      createdAt: DateTime(2026, 10, day),
    );

void main() {
  late FakeBackend db;
  setUp(() => db = FakeBackend());

  test('listFromUserData tolérant, trié du plus récent', () {
    expect(MyReport.listFromUserData(null), isEmpty);
    expect(MyReport.listFromUserData({'myReports': 'x'}), isEmpty);
    final l = MyReport.listFromUserData({
      'myReports': [
        _r('a', 1).toMap(),
        {'id': ''},
        'junk',
        _r('b', 5).toMap(),
      ]
    });
    expect(l.map((e) => e.id), ['b', 'a']);
  });

  test('submit renvoie l\'id du signalement', () async {
    final id = await IncidentRepository().submit(kind: 'incident', category: 'autre', message: 'm');
    expect(id, isNotEmpty);
    expect(db.incidents.single['message'], 'm');
  });

  test('watchReplies : ordre chronologique ; watchHasReply', () async {
    final repo = IncidentRepository();
    expect(await repo.watchHasReply('i1').first, isFalse);
    db.replies['i1'] = [
      {'id': 'a', 'text': 'un', 'createdAt': '2026-10-01T00:00:00Z'},
      {'id': 'b', 'text': 'deux', 'createdAt': '2026-10-02T00:00:00Z'},
    ];
    final replies = await repo.watchReplies('i1').first;
    expect(replies.map((r) => r.text), ['un', 'deux']);
    expect(await repo.watchHasReply('i1').first, isTrue);
  });

  testWidgets('liste : pastille Réponse reçue seulement si réponse ; détail', (t) async {
    await UserRepository().setUser('u', {
      'myReports': [_r('i1', 1).toMap(), _r('i2', 2).toMap()],
    });
    db.replies['i1'] = [
      {'id': 'r1', 'text': 'Merci, traité.', 'createdAt': '2026-10-03T00:00:00Z'},
    ];

    await t.pumpWidget(MaterialApp(
      home: MyReportsScreen(
        uid: 'u',
        userRepository: UserRepository(),
        incidentRepository: IncidentRepository(),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text(AppStrings.myReportsReplyReceived), findsOneWidget);
    expect(find.text(AppStrings.myReportsInProgress), findsOneWidget);

    await t.tap(find.text('msg i1'));
    await t.pumpAndSettle();
    expect(find.text('Merci, traité.'), findsOneWidget);
    expect(find.textContaining(AppStrings.myReportsTeamReply), findsOneWidget);
  });

  testWidgets('liste vide', (t) async {
    await UserRepository().setUser('u', {});
    await t.pumpWidget(MaterialApp(
      home: MyReportsScreen(
          uid: 'u', userRepository: UserRepository(), incidentRepository: IncidentRepository()),
    ));
    await t.pumpAndSettle();
    expect(find.text(AppStrings.myReportsEmpty), findsOneWidget);
  });

  testWidgets('openIncidentId ouvre directement le détail', (t) async {
    await UserRepository().setUser('u', {'myReports': [_r('i1', 1).toMap()]});
    await t.pumpWidget(MaterialApp(
      home: MyReportsScreen(
          uid: 'u',
          openIncidentId: 'i1',
          userRepository: UserRepository(),
          incidentRepository: IncidentRepository()),
    ));
    await t.pumpAndSettle();
    expect(find.text(AppStrings.myReportsNoReplyYet), findsOneWidget);
  });
}
