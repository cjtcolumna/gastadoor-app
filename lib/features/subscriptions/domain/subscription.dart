import 'package:freezed_annotation/freezed_annotation.dart';

part 'subscription.freezed.dart';
part 'subscription.g.dart';

/// How often a subscription charges you. The names are what the database
/// stores in the `frequency` column.
enum SubscriptionFrequency { monthly, yearly }

/// A charge that repeats, like Spotify every month. It is a schedule, not
/// money: every time it is due, the database adds a normal expense to your
/// transactions (see `20261108010000_subscriptions_cron.sql`).
@freezed
abstract class Subscription with _$Subscription {
  const factory Subscription({
    required String id,
    required String userId,
    required String name,

    /// What each charge costs, in cents.
    required int amountCents,
    required SubscriptionFrequency frequency,

    /// The date the schedule is counted from (the "Next charge" date picked
    /// in the form). Set by you; never changes by itself.
    required DateTime firstChargeOn,

    /// When the next expense will be added. The database keeps this right.
    required DateTime nextChargeOn,

    /// The account that pays for it.
    required String accountId,
    String? categoryId,

    /// False = paused: nothing is charged until you resume.
    @Default(true) bool active,
    DateTime? createdAt,
  }) = _Subscription;

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);
}
