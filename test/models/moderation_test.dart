import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yame/core/constants/app_strings.dart';
import 'package:yame/core/widgets/moderation_notice.dart';
import 'package:yame/features/driver/driver_status_screen.dart';
import 'package:yame/models/moderation.dart';

void main() {
  final now = DateTime.utc(2026, 10, 8, 12);
  final future = '2026-10-20T00:00:00.000Z';
  final past = '2026-10-01T00:00:00.000Z';

  group('client', () {
    test('absent / active / inconnu = actif', () {
      expect(ModerationState.forClient(null, now: now), isNull);
      expect(ModerationState.forClient({}, now: now), isNull);
      expect(ModerationState.forClient({'moderationStatus': 'active'}, now: now), isNull);
      expect(ModerationState.forClient({'moderationStatus': 'shadow_banned_v2'}, now: now), isNull);
      expect(ModerationState.forClient({'moderationStatus': 42}, now: now), isNull);
    });

    test('blocked : restreint, motif nettoyé, date ignorée', () {
      final s = ModerationState.forClient({
        'moderationStatus': 'blocked',
        'moderationReason': '  Fraude ',
        'moderationUntil': past,
      }, now: now)!;
      expect(s.kind, ModerationKind.blocked);
      expect(s.reason, 'Fraude');
    });

    test('suspended : date future ou absente = restreint, échue = actif', () {
      expect(
          ModerationState.forClient(
              {'moderationStatus': 'suspended', 'moderationUntil': future}, now: now)!
              .until,
          DateTime.parse(future));
      expect(ModerationState.forClient({'moderationStatus': 'suspended'}, now: now)!.until, isNull);
      expect(
          ModerationState.forClient(
              {'moderationStatus': 'suspended', 'moderationUntil': past}, now: now),
          isNull);
    });

    test('motif vide ou non texte -> null', () {
      expect(
          ModerationState.forClient(
              {'moderationStatus': 'blocked', 'moderationReason': '  '}, now: now)!
              .reason,
          isNull);
    });
  });

  group('chauffeur', () {
    test('seul status == suspended restreint', () {
      for (final st in ['approved', 'pending_verification', 'rejected', 'nouveau', null]) {
        expect(ModerationState.forDriver({'status': st}, now: now), isNull, reason: '$st');
      }
      expect(ModerationState.forDriver(null, now: now), isNull);
      final s = ModerationState.forDriver(
          {'status': 'suspended', 'suspendedUntil': future, 'moderationReason': 'Plaintes'},
          now: now)!;
      expect(s.kind, ModerationKind.suspended);
      expect(s.reason, 'Plaintes');
    });

    test('suspension échue ou suspendedUntil null', () {
      expect(ModerationState.forDriver({'status': 'suspended', 'suspendedUntil': past}, now: now),
          isNull);
      expect(ModerationState.forDriver({'status': 'suspended', 'suspendedUntil': null}, now: now),
          isNotNull);
    });
  });

  testWidgets('DriverStatusScreen suspendu : avis avec motif et échéance', (t) async {
    await t.pumpWidget(MaterialApp(
      home: DriverStatusScreen(
        rejected: false,
        suspension: ModerationState(
          kind: ModerationKind.suspended,
          until: DateTime(2026, 10, 20),
          reason: 'Plaintes répétées',
        ),
      ),
    ));
    expect(find.text(AppStrings.moderationSuspendedTitle), findsOneWidget);
    expect(find.text(AppStrings.moderationDriverCannotGoOnline), findsOneWidget);
    expect(find.textContaining('Plaintes répétées'), findsOneWidget);
    expect(find.textContaining('20/10/2026'), findsOneWidget);
  });

  testWidgets('ModerationBanner client bloqué', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ModerationBanner(
          state: ModerationState(kind: ModerationKind.blocked, reason: 'Abus'),
        ),
      ),
    ));
    expect(find.text(AppStrings.moderationBlockedTitle), findsOneWidget);
    expect(find.text(AppStrings.moderationClientCannotRequest), findsOneWidget);
    expect(find.textContaining('Abus'), findsOneWidget);
  });
}
