/// Weight unit conversion. All weights are stored in kilograms; these helpers
/// convert to and from whatever unit the user has chosen for display/input.
///
/// A unit is more than a scale factor here. Each one counts by its own step —
/// 2.5 kg or 5 lb — and that step is what a fresh slot progresses by, and what a
/// converted target is snapped to. Those live here rather than in
/// `progression.dart` because they are facts about the unit; the axis-shaped
/// half of the same question ([ProgressionMode.defaultIncrement]) stays there.
library;

import 'package:flutter/widgets.dart' show Locale;

import '../data/progression.dart';
import '../l10n/app_localizations.dart';

const double kKgPerLb = 0.45359237;

/// Converts a canonical kilogram value into the display unit ('kg' or 'lb').
double toDisplayWeight(double kg, String unit) =>
    unit == 'lb' ? kg / kKgPerLb : kg;

/// Converts a value typed by the user (in [unit]) back into kilograms.
double toKg(double display, String unit) =>
    unit == 'lb' ? display * kKgPerLb : display;

/// The suffix shown next to weights and volumes, in the app's language.
String unitSuffix(AppLocalizations l10n, String unit) =>
    unit == 'lb' ? l10n.unitLbSuffix : l10n.unitKgSuffix;

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
double snapToUnitStep(double kg, String unit) {
  final step = unitStepKg(unit);
  return (kg / step).roundToDouble() * step;
}

/// The grid a weight that arrived from somewhere else is put back onto: a
/// quarter of a kilogram, or half a pound.
///
/// Not the same fraction in both units, because the smallest rate each gym
/// actually uses is not the same: 1.25 kg is the pair of 1.25s a metric gym
/// steps by and has to survive, while no pounds gym counts below the half.
const double kTidyGridLb = 0.5;
const double kTidyGridKg = 0.25;

/// [kg] rounded to the nearest [kTidyGridKg] or [kTidyGridLb] of [unit].
///
/// This is a repair, not a preference. A wire format that carries kilograms to
/// two decimals (`ByteWriter.fixed2`) cannot hold a pounds figure exactly: 2.5 lb
/// is 1.1339809 kg, arrives as 1.13, and reads back as 2.49 lb. The error is at
/// most a hundredth of a kilogram, so either grid is coarse enough to put the
/// number back where it started. Only a value that has travelled is put through
/// this — nothing already on the phone is rounded.
double snapToTidyGrid(double kg, String unit) {
  final grid = unit == 'lb' ? kTidyGridLb : kTidyGridKg;
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
