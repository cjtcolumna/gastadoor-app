import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/core/utils/dates.dart';
import 'package:gastadoor/core/widgets/amount_hero_field.dart';
import 'package:gastadoor/features/accounts/data/accounts_provider.dart';
import 'package:gastadoor/features/accounts/domain/account.dart';
import 'package:gastadoor/features/categories/data/categories_repository.dart';
import 'package:gastadoor/features/categories/domain/category.dart';
import 'package:gastadoor/features/subscriptions/data/subscriptions_provider.dart';
import 'package:gastadoor/features/subscriptions/domain/subscription.dart';
import 'package:gastadoor/features/subscriptions/presentation/subscriptions_home_card.dart';
import 'package:gastadoor/features/subscriptions/presentation/subscriptions_screen.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';

/// What the form asked to add.
typedef Added = ({
  String name,
  int cents,
  SubscriptionFrequency frequency,
  DateTime date,
  String accountId,
  String? categoryId,
});

/// What the form asked to save: the subscription, and the schedule date
/// (null = the schedule was left alone).
typedef Saved = (Subscription, DateTime?);

/// Keeps subscriptions in memory instead of Supabase.
class FakeSubscriptionsNotifier extends SubscriptionsNotifier {
  FakeSubscriptionsNotifier(this.start);

  final List<Subscription> start;
  final added = <Added>[];
  final saved = <Saved>[];
  final paused = <(String, bool)>[];
  final removed = <String>[];

  @override
  Future<List<Subscription>> build() async => start;

  @override
  Future<void> add({
    required String name,
    required int amountCents,
    required SubscriptionFrequency frequency,
    required DateTime firstChargeOn,
    required String accountId,
    String? categoryId,
  }) async => added.add((
    name: name,
    cents: amountCents,
    frequency: frequency,
    date: firstChargeOn,
    accountId: accountId,
    categoryId: categoryId,
  ));

  @override
  Future<void> save(
    Subscription subscription, {
    DateTime? firstChargeOn,
  }) async => saved.add((subscription, firstChargeOn));

  @override
  Future<void> setActive(String id, {required bool active}) async =>
      paused.add((id, active));

  @override
  Future<void> remove(String id) async => removed.add(id);
}

class FakeAccounts extends AccountsNotifier {
  @override
  Future<List<Account>> build() async => const [
    Account(id: 'gotyme', userId: 'u', name: 'GoTyme', type: AccountType.bank),
    Account(id: 'cash', userId: 'u', name: 'Cash', type: AccountType.cash),
  ];
}

const _categories = [
  Category(
    id: 'music',
    userId: 'u',
    name: 'Music',
    kind: TransactionKind.expense,
    icon: 'music',
    color: 'pink',
  ),
  Category(
    id: 'salary',
    userId: 'u',
    name: 'Salary',
    kind: TransactionKind.income,
  ),
];

Subscription sub(
  String id,
  String name,
  int cents, {
  SubscriptionFrequency frequency = SubscriptionFrequency.monthly,
  DateTime? next,
  bool active = true,
  String? categoryId,
}) => Subscription(
  id: id,
  userId: 'u',
  name: name,
  amountCents: cents,
  frequency: frequency,
  firstChargeOn: DateTime(2026, 10, 4),
  nextChargeOn: next ?? DateTime(2026, 12, 4),
  accountId: 'gotyme',
  categoryId: categoryId,
  active: active,
);

void main() {
  late FakeSubscriptionsNotifier fake;

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    List<Subscription> subscriptions = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    fake = FakeSubscriptionsNotifier(subscriptions);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionsProvider.overrideWith(() => fake),
          accountsProvider.overrideWith(FakeAccounts.new),
          accountBalancesProvider.overrideWith(
            (ref) async => {'gotyme': 500000, 'cash': 10000},
          ),
          categoriesProvider.overrideWith((ref) async => _categories),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  final nameField = find.byKey(const Key('subscription-name'));
  final amountField = find.descendant(
    of: find.byType(AmountHeroField),
    matching: find.byType(TextFormField),
  );

  Future<void> openAddForm(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Add subscription'));
    await tester.pumpAndSettle();
  }

  /// Opens the edit form by tapping the row with this [name].
  Future<void> openEditForm(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  /// The form's big button. (The last one is the one on top.)
  Finder saveButton(String label) =>
      find.widgetWithText(FilledButton, label).last;

  Future<void> tapSave(WidgetTester tester, String label) async {
    await tester.tap(saveButton(label));
    await tester.pumpAndSettle();
  }

  /// Taps something in the form, scrolling it into view first.
  Future<void> tapInForm(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('Subscriptions screen', () {
    testWidgets('shows what you pay every month and every year', (
      tester,
    ) async {
      await pump(
        tester,
        const SubscriptionsScreen(),
        subscriptions: [
          sub('a', 'Spotify', 14900),
          sub('b', 'Domain', 120000, frequency: SubscriptionFrequency.yearly),
          sub('c', 'Gym', 50000, active: false),
        ],
      );

      expect(find.text('Every month'), findsOneWidget);
      // Spotify 149 a month + Domain 1,200 a year = 249 a month. The paused
      // gym is not counted.
      expect(find.text('₱249.00'), findsOneWidget);
      expect(find.text('₱2,988.00 a year · 2 active'), findsOneWidget);
    });

    testWidgets('lists each subscription with its price and next charge', (
      tester,
    ) async {
      await pump(
        tester,
        const SubscriptionsScreen(),
        subscriptions: [
          sub('a', 'Spotify', 14900, categoryId: 'music'),
          sub('b', 'Domain', 120000, frequency: SubscriptionFrequency.yearly),
        ],
      );

      expect(find.text('Spotify'), findsOneWidget);
      expect(find.text('₱149.00'), findsOneWidget);
      expect(find.text('per month'), findsOneWidget);
      expect(find.text('Domain'), findsOneWidget);
      expect(find.text('per year'), findsOneWidget);
      expect(find.textContaining('Dec 4 · '), findsNWidgets(2));
    });

    testWidgets('paused ones sit in their own Paused section', (tester) async {
      await pump(
        tester,
        const SubscriptionsScreen(),
        subscriptions: [
          sub('a', 'Spotify', 14900),
          sub('c', 'Gym', 50000, active: false),
        ],
      );

      expect(find.text('Paused'), findsNWidgets(2)); // the title and the row
      expect(find.textContaining('Dec 4 · '), findsOneWidget); // only Spotify
    });

    testWidgets('with none, it invites you to add the first one', (
      tester,
    ) async {
      await pump(tester, const SubscriptionsScreen());

      expect(find.textContaining('Pay for Spotify, Netflix'), findsOneWidget);
      expect(find.text('Nothing is charged right now'), findsOneWidget);
    });
  });

  group('Add form', () {
    testWidgets('adds a monthly subscription from the first account', (
      tester,
    ) async {
      await pump(
        tester,
        const SubscriptionsScreen(),
        subscriptions: [sub('x', 'Existing', 100)],
      );
      await openAddForm(tester);

      await tester.enterText(nameField, 'Spotify');
      await tester.enterText(amountField, '149');
      await tapSave(tester, 'Add subscription');

      expect(fake.added, [
        (
          name: 'Spotify',
          cents: 14900,
          frequency: SubscriptionFrequency.monthly,
          date: dateOnly(DateTime.now()),
          accountId: 'gotyme',
          categoryId: null,
        ),
      ]);
    });

    testWidgets('you can pick yearly, a category and another account', (
      tester,
    ) async {
      await pump(
        tester,
        const SubscriptionsScreen(),
        subscriptions: [sub('x', 'Existing', 100)],
      );
      await openAddForm(tester);

      await tester.enterText(nameField, 'Domain');
      await tester.enterText(amountField, '1,200');
      await tapInForm(tester, find.text('Yearly'));
      await tapInForm(tester, find.text('Music'));
      await tapInForm(tester, find.widgetWithText(ChoiceChip, 'Cash'));
      await tapSave(tester, 'Add subscription');

      final added = fake.added.single;
      expect(added.frequency, SubscriptionFrequency.yearly);
      expect(added.cents, 120000);
      expect(added.categoryId, 'music');
      expect(added.accountId, 'cash');
    });

    testWidgets('tapping the chosen category again clears it', (tester) async {
      await pump(
        tester,
        const SubscriptionsScreen(),
        subscriptions: [sub('x', 'Existing', 100)],
      );
      await openAddForm(tester);

      await tester.enterText(nameField, 'Spotify');
      await tester.enterText(amountField, '149');
      await tapInForm(tester, find.text('Music'));
      await tapInForm(tester, find.text('Music'));
      await tapSave(tester, 'Add subscription');

      expect(fake.added.single.categoryId, isNull);
    });

    testWidgets('the chosen Monthly / Yearly option is highlighted', (
      tester,
    ) async {
      await pump(
        tester,
        const SubscriptionsScreen(),
        subscriptions: [sub('x', 'Existing', 100)],
      );
      await openAddForm(tester);

      /// The fill behind one segment of the Monthly | Yearly switch.
      Color? fill(String label) {
        final segment = find.widgetWithText(TextButton, label);
        final material = find
            .descendant(of: segment, matching: find.byType(Material))
            .first;
        return tester.widget<Material>(material).color;
      }

      // Monthly is chosen to begin with.
      expect(fill('Monthly'), AppTheme.selectedFill);
      expect(fill('Yearly'), Colors.white);

      await tapInForm(tester, find.text('Yearly'));
      expect(fill('Yearly'), AppTheme.selectedFill);
      expect(fill('Monthly'), Colors.white);
    });

    testWidgets('only expense categories are offered', (tester) async {
      await pump(
        tester,
        const SubscriptionsScreen(),
        subscriptions: [sub('x', 'Existing', 100)],
      );
      await openAddForm(tester);

      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Salary'), findsNothing);
    });

    testWidgets('a name and an amount are required', (tester) async {
      await pump(
        tester,
        const SubscriptionsScreen(),
        subscriptions: [sub('x', 'Existing', 100)],
      );
      await openAddForm(tester);

      await tapSave(tester, 'Add subscription');

      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(fake.added, isEmpty);
    });

    testWidgets('the next charge date opens the calendar', (tester) async {
      await pump(
        tester,
        const SubscriptionsScreen(),
        subscriptions: [sub('x', 'Existing', 100)],
      );
      await openAddForm(tester);
      expect(find.text(fullDate(DateTime.now())), findsOneWidget);

      await tapInForm(tester, find.byKey(const Key('date-next-charge')));
      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('fits on a narrow 320px phone', (tester) async {
      await pump(
        tester,
        const SubscriptionsScreen(),
        subscriptions: [
          sub(
            'x',
            'A subscription with a really very long name indeed',
            123456789,
            frequency: SubscriptionFrequency.yearly,
            categoryId: 'music',
          ),
        ],
      );
      tester.view.physicalSize = const Size(320, 700);
      await openAddForm(tester);

      await tester.enterText(nameField, 'Alexandra Montgomery Streaming Plus');
      await tester.enterText(amountField, '99,999.99');
      await tapInForm(tester, find.text('Yearly'));

      // Flutter fails a test on any overflow, so this must be empty.
      expect(tester.takeException(), isNull);
    });
  });

  group('Edit form', () {
    final spotify = sub('a', 'Spotify', 14900, categoryId: 'music');

    testWidgets('starts with what was saved', (tester) async {
      await pump(tester, const SubscriptionsScreen(), subscriptions: [spotify]);
      await openEditForm(tester, 'Spotify');

      expect(find.text('Edit subscription'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(nameField).controller!.text,
        'Spotify',
      );
      expect(
        tester.widget<TextFormField>(amountField).controller!.text,
        '149.00',
      );
    });

    testWidgets('changing the price leaves the schedule alone', (tester) async {
      await pump(tester, const SubscriptionsScreen(), subscriptions: [spotify]);
      await openEditForm(tester, 'Spotify');

      await tester.enterText(amountField, '169');
      await tapSave(tester, 'Save');

      final (saved, scheduleDate) = fake.saved.single;
      expect(saved.amountCents, 16900);
      expect(saved.name, 'Spotify');
      expect(saved.accountId, 'gotyme');
      expect(saved.categoryId, 'music');
      // No new date is sent, so the database keeps the schedule as it is.
      expect(scheduleDate, isNull);
    });

    testWidgets('picking a date sends it, even if it is the same one', (
      tester,
    ) async {
      // A date far ahead, so the calendar opens right on it.
      final farAway = sub('a', 'Spotify', 14900, next: DateTime(2030, 1, 15));
      await pump(tester, const SubscriptionsScreen(), subscriptions: [farAway]);
      await openEditForm(tester, 'Spotify');

      // The calendar opens on the saved date. OK confirms it.
      await tapInForm(tester, find.byKey(const Key('date-next-charge')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tapSave(tester, 'Save');

      expect(fake.saved.single.$2, DateTime(2030, 1, 15));
    });

    testWidgets('switching to yearly sends the shown date too', (tester) async {
      await pump(tester, const SubscriptionsScreen(), subscriptions: [spotify]);
      await openEditForm(tester, 'Spotify');

      await tapInForm(tester, find.text('Yearly'));
      await tapSave(tester, 'Save');

      final (saved, scheduleDate) = fake.saved.single;
      expect(saved.frequency, SubscriptionFrequency.yearly);
      expect(scheduleDate, isNotNull);
    });

    testWidgets('can be paused', (tester) async {
      await pump(tester, const SubscriptionsScreen(), subscriptions: [spotify]);
      await openEditForm(tester, 'Spotify');

      await tester.tap(find.text('Pause subscription'));
      await tester.pumpAndSettle();

      expect(fake.paused, [('a', false)]);
    });

    testWidgets('a paused one can be resumed', (tester) async {
      await pump(
        tester,
        const SubscriptionsScreen(),
        subscriptions: [sub('c', 'Gym', 50000, active: false)],
      );
      await openEditForm(tester, 'Gym');

      expect(find.text('Pause subscription'), findsNothing);
      await tester.tap(find.text('Resume subscription'));
      await tester.pumpAndSettle();

      expect(fake.paused, [('c', true)]);
    });

    testWidgets('deleting asks first, and says History is kept', (
      tester,
    ) async {
      await pump(tester, const SubscriptionsScreen(), subscriptions: [spotify]);
      await openEditForm(tester, 'Spotify');

      await tester.tap(find.text('Delete subscription'));
      await tester.pumpAndSettle();
      expect(find.textContaining('stay in your History'), findsOneWidget);

      // "No" changes nothing.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.removed, isEmpty);

      await tester.tap(find.text('Delete subscription'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(fake.removed, ['a']);
    });
  });

  group('Home section', () {
    Future<void> pumpHome(
      WidgetTester tester,
      List<Subscription> subscriptions,
    ) => pump(
      tester,
      const Scaffold(
        body: SingleChildScrollView(child: SubscriptionsHomeSection()),
      ),
      subscriptions: subscriptions,
    );

    testWidgets('shows the subscription that charges next', (tester) async {
      await pumpHome(tester, [
        sub('a', 'Later', 20000, next: DateTime(2026, 12, 20)),
        sub('b', 'Spotify', 14900, next: DateTime(2026, 12, 5)),
        sub('c', 'Paused', 100, next: DateTime(2026, 11, 1), active: false),
      ]);

      expect(find.text('Next: Spotify'), findsOneWidget);
      expect(find.textContaining('Dec 5 · '), findsOneWidget);
      expect(find.text('₱149.00'), findsOneWidget);
    });

    testWidgets('invites you to add one when there are none', (tester) async {
      await pumpHome(tester, const []);
      expect(find.text('Subscriptions'), findsOneWidget);
      expect(find.text('Add subscription'), findsOneWidget);
    });

    testWidgets('says so when everything is paused', (tester) async {
      await pumpHome(tester, [sub('c', 'Gym', 50000, active: false)]);
      expect(find.text('All paused'), findsOneWidget);
    });
  });
}
