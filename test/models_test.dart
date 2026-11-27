import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neon_xo_admin/models/ad_model.dart';
import 'package:neon_xo_admin/models/admin_model.dart';
import 'package:neon_xo_admin/models/game_model.dart';
import 'package:neon_xo_admin/models/user_model.dart';
import 'package:neon_xo_admin/services/admin_log_service.dart';
import 'package:neon_xo_admin/services/input_sanitizer.dart';

void main() {
  final when = DateTime(2026, 11, 27, 9, 5);
  final stamp = Timestamp.fromDate(when);

  group('AdModel', () {
    test('reads all fields', () {
      final ad = AdModel.fromMap('ad1', {
        'title': 'Sale',
        'message': 'Half price',
        'imageUrl': 'https://x.com/a.png',
        'countdownSeconds': 20,
        'active': true,
        'createdAt': stamp,
      });
      expect(ad.title, 'Sale');
      expect(ad.countdownSeconds, 20);
      expect(ad.active, isTrue);
      expect(ad.hasImage, isTrue);
      expect(ad.createdAt, when);
    });

    test('defaults: 15 s countdown, inactive, no image', () {
      final ad = AdModel.fromMap('ad2', {'title': 'X'});
      expect(ad.countdownSeconds, AdModel.defaultCountdown);
      expect(AdModel.defaultCountdown, 15);
      expect(ad.active, isFalse);
      expect(ad.hasImage, isFalse);
      expect(ad.createdAt, isNull);
    });

    test('limits match the Firestore rules', () {
      expect(AdModel.maxTitleLength, 60);
      expect(AdModel.maxMessageLength, 200);
      expect(AdModel.maxImageUrlLength, 500);
      expect(AdModel.minCountdown, 5);
      expect(AdModel.maxCountdown, 60);
    });
  });

  group('UserModel', () {
    test('parses stats, dates and blocked status', () {
      final user = UserModel.fromMap('u1', {
        'name': 'Ali',
        'email': 'ali@x.com',
        'createdAt': stamp,
        'emailVerifiedAt': '2026-11-01T10:00:00',
        'gamesPlayed': 10,
        'wins': 4.0,
        'status': 'blocked',
      });
      expect(user.name, 'Ali');
      expect(user.createdAt, when);
      expect(user.emailVerifiedAt, DateTime(2026, 11, 1, 10));
      expect(user.wins, 4);
      expect(user.isBlocked, isTrue);
      expect(user.winRate, 40);
    });

    test('missing data gives safe defaults', () {
      final user = UserModel.fromMap('u2', {});
      expect(user.name, '');
      expect(user.isBlocked, isFalse);
      expect(user.winRate, 0);
    });
  });

  group('GameModel', () {
    test('maps resultForPlayer1 and completedAt', () {
      final game = GameModel.fromMap('g1', {
        'player1Uid': 'u1',
        'opponentType': 'computer',
        'difficulty': 'Hard',
        'resultForPlayer1': 'win',
        'completedAt': stamp,
      });
      expect(game.result, 'win');
      expect(game.difficulty, 'Hard');
      expect(game.completedAt, when);
      expect(GameModel.fromMap('g2', {}).completedAt, isNull);
    });
  });

  group('AdminModel', () {
    test('display name falls back from name to email to uid', () {
      expect(const AdminModel(uid: 'id', role: 'admin', name: 'Sara').displayName,
          'Sara');
      expect(const AdminModel(uid: 'id', role: 'admin', email: 's@x.com').displayName,
          's@x.com');
      expect(const AdminModel(uid: 'id', role: 'admin').displayName, 'id');
    });

    test('fromMap / toMap', () {
      final admin = AdminModel.fromMap('a1', {
        'role': 'admin',
        'name': 'Sara',
        'email': 's@x.com',
        'createdAt': stamp,
      });
      expect(admin.createdAt, when);
      expect(admin.toMap(), {'role': 'admin', 'name': 'Sara', 'email': 's@x.com'});
    });
  });

  group('Activity log', () {
    test('every action name round-trips and has a label', () {
      for (final action in AdminAction.values) {
        expect(AdminAction.fromName(action.name), action);
        expect(action.label, isNotEmpty);
      }
      expect(AdminAction.fromName('unknown'), isNull);
      expect(AdminAction.fromName(null), isNull);
    });

    test('ad and password actions exist', () {
      expect(AdminAction.fromName('adCreated'), AdminAction.adCreated);
      expect(AdminAction.fromName('adDeleted'), AdminAction.adDeleted);
      expect(AdminAction.fromName('ownPasswordChanged'),
          AdminAction.ownPasswordChanged);
    });

    test('log entry parsing keeps unknown actions readable', () {
      final entry = AdminLogEntry.fromMap('l1', {
        'action': 'somethingNew',
        'adminEmail': 'a@x.com',
        'createdAt': stamp,
      });
      expect(entry.action, isNull);
      expect(entry.actionName, 'somethingNew');
      expect(entry.createdAt, when);
      expect(entry.details, '');
    });

    test('formatLogTime pads day, month, hour and minute', () {
      expect(formatLogTime(DateTime(2026, 3, 4, 7, 5)), '04/03 07:05');
    });
  });

  group('InputSanitizer', () {
    test('strips control characters, trims and limits length', () {
      expect(InputSanitizer.clean(' a\u0000b\u001Fc ', maxLength: 10), 'abc');
      expect(InputSanitizer.clean('line1\nline2', maxLength: 50), 'line1\nline2');
      expect(InputSanitizer.clean('x' * 100, maxLength: 60).length, 60);
    });

    test('only https image links are accepted', () {
      expect(InputSanitizer.isSafeHttpsUrl('https://cdn.x.com/a.png'), isTrue);
      expect(InputSanitizer.isSafeHttpsUrl('http://cdn.x.com/a.png'), isFalse);
      expect(InputSanitizer.isSafeHttpsUrl('ftp://x.com'), isFalse);
      expect(InputSanitizer.isSafeHttpsUrl('https://'), isFalse);
      expect(InputSanitizer.isSafeHttpsUrl(''), isFalse);
    });
  });
}
