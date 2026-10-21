import 'package:flutter/material.dart';

/// Colors that mean something in a money app, used everywhere the same way.
/// Read them with `context.appColors.income` etc.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.income,
    required this.incomeSoft,
    required this.expense,
    required this.expenseSoft,
    required this.warning,
    required this.border,
  });

  /// Money coming in (salary, gifts) and positive balances.
  final Color income;
  final Color incomeSoft;

  /// Money going out, and amounts you owe.
  final Color expense;
  final Color expenseSoft;

  /// "Careful": e.g. a budget that is almost used up.
  final Color warning;

  /// Thin lines around cards and fields.
  final Color border;

  static const light = AppColors(
    income: Color(0xFF1E8E5A),
    incomeSoft: Color(0xFFE3F4EA),
    expense: Color(0xFFD64545),
    expenseSoft: Color(0xFFFBE7E7),
    warning: Color(0xFFE59A1A),
    border: Color(0xFFE7EAEE),
  );

  @override
  AppColors copyWith({
    Color? income,
    Color? incomeSoft,
    Color? expense,
    Color? expenseSoft,
    Color? warning,
    Color? border,
  }) => AppColors(
    income: income ?? this.income,
    incomeSoft: incomeSoft ?? this.incomeSoft,
    expense: expense ?? this.expense,
    expenseSoft: expenseSoft ?? this.expenseSoft,
    warning: warning ?? this.warning,
    border: border ?? this.border,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      income: Color.lerp(income, other.income, t)!,
      incomeSoft: Color.lerp(incomeSoft, other.incomeSoft, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseSoft: Color.lerp(expenseSoft, other.expenseSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  /// The app's money colors. Falls back to the light set if a screen
  /// is shown without the app theme (for example in a test).
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

/// GastaDoor's look: light, clean, lots of white, money green as the accent.
class AppTheme {
  const AppTheme._();

  static const _seed = Color(0xFF2E7D5B);

  /// The soft grey-white behind everything; cards sit on it in pure white.
  static const background = Color(0xFFF5F7F6);

  /// The app's font: modern and friendly, and stays sharp at small sizes.
  /// Must match the `family:` name in pubspec.yaml.
  static const fontFamily = 'PlusJakartaSans';

  static ThemeData light() {
    const appColors = AppColors.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      primary: _seed,
      surface: Colors.white,
    );
    final radius = BorderRadius.circular(16);
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // Every Text in the app uses this font unless it says otherwise.
      // The font files are bundled in assets/fonts (see pubspec.yaml).
      fontFamily: fontFamily,
    );
    final text = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: background,
      extensions: const [appColors],
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: appColors.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: appColors.border, space: 1),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: appColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: appColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        // A selected chip is shown by its tinted background, so its own
        // rounded icon stays visible instead of Flutter's square check mark.
        selectedColor: scheme.primaryContainer,
        showCheckmark: false,
        side: BorderSide(color: appColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: appColors.border),
        ),
        // If a segmented button ever shows a check mark, make it rounded.
        selectedIcon: const Icon(Icons.check_rounded),
      ),
      // Back and close buttons in app bars use rounded icons too.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(Icons.arrow_back_rounded),
        closeButtonIconBuilder: (_) => const Icon(Icons.close_rounded),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
