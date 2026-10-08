import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yame/core/constants/app_strings.dart';
import 'package:yame/features/support/my_reports_screen.dart';
import 'package:yame/models/my_report.dart';
import 'package:yame/repositories/incident_repository.dart';
import 'package:yame/repositories/ride_repository.dart';
import 'package:yame/repositories/user_repository.dart';

MyReport _r(String id, int day) => MyReport(
      id: id,
      kind: 'incident',
      category: 'securite',
      message: 'msg $id',
      createdAt: DateTime(2026, 10, day),
    );

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

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

  test('addIncident renvoie l\'id ; rememberReport mémorise et plafonne', () async {
    final id = await RideRepository(db).addIncident({'k': 1});
    expect(id, isNotEmpty);
    final repo = IncidentRepository(db);
    await UserRepository(db).setUser('u', {'name': 'N'});
    for (var i = 0; i < MyReport.maxStored + 5; i++) {
      await repo.rememberReport(
          'u',
          MyReport(id: 'i$i', kind: 'incident', category: 'autre', message: 'm',
              createdAt: DateTime(2026, 1, 1).add(Duration(minutes: i))));
    }
    final data = (await UserRepository(db).getUser('u')).data()!;
    expect(data['name'], 'N');
    final list = MyReport.listFromUserData(data);
    expect(list.length, MyReport.maxStored);
    expect(list.first.id, 'i${MyReport.maxStored + 4}');
  });

  test('watchReplies : ordre chronologique ; watchHasReply', () async {
    final repo = IncidentRepository(db);
    expect(await repo.watchHasReply('i1').first, isFalse);
    await db.doc('incidents/i1/replies/b').set({'text': 'deux', 'createdAt': '2026-10-02T00:00:00Z'});
    await db.doc('incidents/i1/replies/a').set({'text': 'un', 'createdAt': '2026-10-01T00:00:00Z'});
    final replies = await repo.watchReplies('i1').first;
    expect(replies.map((r) => r.text), ['un', 'deux']);
    expect(await repo.watchHasReply('i1').first, isTrue);
  });

  testWidgets('liste : pastille Réponse reçue seulement si réponse ; détail', (t) async {
    await UserRepository(db).setUser('u', {
      'myReports': [_r('i1', 1).toMap(), _r('i2', 2).toMap()],
    });
    // Statut 'answered' sur le parent : jamais lu, sans effet.
    await db.doc('incidents/i1').set({'status': 'answered', 'reporterUid': 'u'});
    await db.doc('incidents/i1/replies/r1').set({'text': 'Merci, traité.', 'createdAt': '2026-10-03T00:00:00Z'});

    await t.pumpWidget(MaterialApp(
      home: MyReportsScreen(
        uid: 'u',
        userRepository: UserRepository(db),
        incidentRepository: IncidentRepository(db),
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
    await UserRepository(db).setUser('u', {});
    await t.pumpWidget(MaterialApp(
      home: MyReportsScreen(
          uid: 'u', userRepository: UserRepository(db), incidentRepository: IncidentRepository(db)),
    ));
    await t.pumpAndSettle();
    expect(find.text(AppStrings.myReportsEmpty), findsOneWidget);
  });

  testWidgets('openIncidentId ouvre directement le détail', (t) async {
    await UserRepository(db).setUser('u', {'myReports': [_r('i1', 1).toMap()]});
    await t.pumpWidget(MaterialApp(
      home: MyReportsScreen(
          uid: 'u',
          openIncidentId: 'i1',
          userRepository: UserRepository(db),
          incidentRepository: IncidentRepository(db)),
    ));
    await t.pumpAndSettle();
    expect(find.text(AppStrings.myReportsNoReplyYet), findsOneWidget);
  });
}
