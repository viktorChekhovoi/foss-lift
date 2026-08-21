/// Converts stored kilogram weights to the selected display unit; unit-specific increments and snapping rules live here as well.

library;

import 'package:flutter/widgets.dart' show Locale;

import '../data/progression.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';

const double kKgPerLb = 0.45359237;

/// Converts a canonical kilogram value into the display unit ('kg' or 'lb').
double toDisplayWeight(double kg, String unit) =>
    unit == 'lb' ? kg / kKgPerLb : kg;

/// Converts a value typed by the user (in [unit]) back into kilograms.
double toKg(double display, String unit) =>
    unit == 'lb' ? display * kKgPerLb : display;

/// The suffix shown next to weights and volumes, in the app's language.
///
/// A symbol rather than a word, and it is never re-cased: "kg" is kg in a
/// shouted column heading as much as in a sentence, and "KG" is not a unit
/// anybody writes.
String unitSuffix(AppLocalizations l10n, String unit) =>
    unit == 'lb' ? l10n.unitLbSuffix : l10n.unitKgSuffix;

/// What a weight nobody has chosen yet reads as: a slot waiting for a number,
/// not a lift done under no load.
const String kUnsetWeight = '—';

/// The number alone, for somewhere that already names the unit — a column with
/// a unit heading over it, or a field with the unit in its suffix.
///
/// Null or zero is a weight nobody has picked, and reads [kUnsetWeight].
String fmtWeightValue(double? kg, String unit) => kg == null || kg == 0
    ? kUnsetWeight
    : fmtWeight(toDisplayWeight(kg, unit));

/// A weight and its unit as one string — "100 kg".
///
/// **The only place the two are joined.** The join is the language's own
/// `unitWeightShort` pattern rather than a space typed in Dart, so a language
/// that spaces or orders them differently is obeyed everywhere rather than on
/// most screens. An unset weight comes back as the bare [kUnsetWeight]: a dash
/// with a unit after it is a unit belonging to nothing.
String weightWithUnit(AppLocalizations l10n, double? kg, String unit) {
  final value = fmtWeightValue(kg, unit);
  return kg == null || kg == 0
      ? value
      : l10n.unitWeightShort(value, unitSuffix(l10n, unit));
}

/// The unit one movement is read and typed in: its own if it has been given
/// one, the app's otherwise.
///
/// **The only place the two are resolved.** Every screen that shows a weight
/// belonging to a particular exercise goes through this, so a movement cannot
/// read as pounds on the board and kilograms in the builder — and the same
/// answer is what its step rates, its fine grid and its warm-up ladder are
/// computed in. A screen showing a figure that spans movements (session volume,
/// the weight moved in a week) has no exercise to ask about and uses the
/// app-wide unit, which is the only unit a sum of several movements can be in.
String unitForExercise(String appUnit, String? override) => override ?? appUnit;

/// The three countries that weigh a barbell in pounds. Everywhere else is
/// metric, so the list is short enough to write down.
const Set<String> kPoundCountries = {'US', 'LR', 'MM'};

/// The unit to offer someone who has not chosen one, from the phone's own
/// locale list: pounds where the country says so, kilograms otherwise.
///
/// A guess, and only ever a starting point — the first-run question asks, and
/// this decides which answer is already selected. A locale with no country in
/// it (bare `en`) is not the United States.
String localeDefaultUnit(Iterable<Locale> locales) {
  for (final locale in locales) {
    final country = locale.countryCode;
    if (country == null || country.isEmpty) continue;
    return kPoundCountries.contains(country.toUpperCase()) ? 'lb' : 'kg';
  }
  return 'kg';
}

/// The step a gym counting in [unit] loads by, as kilograms: the pair of 1.25s
/// that makes 2.5 kg, or the pair of 2.5 lb plates that makes 5 lb.
///
/// This is the granularity a converted target is snapped to and the default a
/// weight-axis slot steps by, which are deliberately the same number: a step
/// that lands somewhere unloadable is a step nobody can take.
/// What a pounds gym counts by, in pounds. The kilogram half of the pair is
/// [ProgressionMode.defaultIncrement], where the other axes' defaults are.
const double kPoundStep = 5;

double unitStepKg(String unit) => unit == 'lb'
    ? toKg(kPoundStep, 'lb')
    : ProgressionMode.weight.defaultIncrement;

/// [mode]'s default step up in kilograms (or reps, or seconds), for a gym
/// counting in [unit].
///
/// Only the weight axis has a unit at all — reps are reps and seconds are
/// seconds in every gym on earth.
double defaultIncrementFor(ProgressionMode mode, String unit) =>
    mode == ProgressionMode.weight ? unitStepKg(unit) : mode.defaultIncrement;

/// [mode]'s default back-off, twice its step up — see
/// [ProgressionMode.defaultDeload].
double defaultDeloadFor(ProgressionMode mode, String unit) =>
    defaultIncrementFor(mode, unit) * 2;

/// [kg] rounded to the nearest step a gym counting in [unit] can load.
///
/// 100 kg is 220.46 lb, which is not a bar anybody sets; snapped, it is 220 lb.
/// Only a *target* is ever put through this — what was actually lifted is
/// history and is never rewritten.
///
/// This is the coarse answer, and a unit switch is the one caller left: it
/// re-plates a whole gym, so landing on a number a pounds gym recognises is
/// worth moving the bar for. A weight the app worked out for itself — a
/// percentage of a training max, a back-off rung — goes through
/// [snapToFineGrid] instead, because rounding 48.75 up to 50 makes the app
/// disagree with its own arithmetic.
double snapToUnitStep(double kg, String unit) {
  final step = unitStepKg(unit);
  return (kg / step).roundToDouble() * step;
}

/// A figure the app ships in kilograms, as the number a gym counting in [unit]
/// would actually load.
///
/// The library's programs are written down in kilograms, so every load and
/// every step in one is a conversion on a pounds phone: a 45 kg training max
/// arrives as 99.208 lb and a 2.5 kg step as 5.512. Neither is a bar anybody
/// sets or a pair of plates anybody owns, so both are put on the coarse step —
/// [snapToUnitStep] — on the way in.
///
/// A kilogram phone gets the number exactly as it was written. There is nothing
/// to convert, and snapping there would only move it: a 12 kg lateral raise is
/// 12 kg because the program says 12, not because 12.5 was unavailable.
double asLoadedIn(double kg, String unit) =>
    unit == 'kg' ? kg : snapToUnitStep(kg, unit);

/// The finest a weight the app was not handed is expressed to: an eighth of a
/// kilogram, or a quarter of a pound.
///
/// Not the step a gym counts by ([unitStepKg]) and not what a slot progresses
/// in. Three callers, one question — how precisely does the app hold a weight it
/// worked out rather than one somebody typed:
///
/// - a percentage keeps the arithmetic that made it (65% of 75 kg is 48.75, and
///   the coarse step would call that 50);
/// - a converted figure loses its tail before it reaches a set row;
/// - a step rate decoded from a routine code is repaired. `ByteWriter.fixed2`
///   carries hundredths of a kilogram and cannot hold a pounds figure exactly:
///   2.5 lb is 1.1339809 kg, goes out as 1.13 and reads back as 2.49 lb. The
///   error is at most a hundredth of a kilogram and half this grid is six times
///   that, so the number lands back where it started.
///
/// The two units differ because they are read at different resolutions: an
/// eighth of a kilogram and a quarter of a pound are within a gram of each
/// other. Both leave the smallest rate a gym actually uses alone — the 1.25 kg
/// pair a metric gym steps by, the 2.5 lb pair a pounds one does.
///
/// Only a weight the app computed or decoded goes through this. Nothing already
/// on the phone is rounded.
const double kFineGridKg = 0.125;
const double kFineGridLb = 0.25;

double fineGridKg(String unit) =>
    unit == 'lb' ? toKg(kFineGridLb, 'lb') : kFineGridKg;

/// [kg] put onto [fineGridKg], measured in [unit] so a pounds gym lands on a
/// quarter pound rather than on a quarter pound's worth of kilograms.
double snapToFineGrid(double kg, String unit) {
  final grid = unit == 'lb' ? kFineGridLb : kFineGridKg;
  return toKg((toDisplayWeight(kg, unit) / grid).roundToDouble() * grid, unit);
}

/// Whether [kg] is (near enough) the default [mode] steps by in [unit].
///
/// The epsilon is what makes the swap on a unit switch safe: 5 lb stored as
/// 2.2679618500000003 kg has to still read as "the pounds default" when the
/// user switches back, while 2.5 kg somebody typed on purpose must not.
bool isDefaultIncrement(double kg, ProgressionMode mode, String unit) =>
    (kg - defaultIncrementFor(mode, unit)).abs() < 1e-6;

/// The [isDefaultIncrement] question for a back-off.
bool isDefaultDeload(double kg, ProgressionMode mode, String unit) =>
    (kg - defaultDeloadFor(mode, unit)).abs() < 1e-6;
