/// Weight unit conversion. All weights are stored in kilograms; these helpers
/// convert to and from whatever unit the user has chosen for display/input.
library;

const double _kgPerLb = 0.45359237;

/// Converts a canonical kilogram value into the display unit ('kg' or 'lb').
double toDisplayWeight(double kg, String unit) =>
    unit == 'lb' ? kg / _kgPerLb : kg;

/// Converts a value typed by the user (in [unit]) back into kilograms.
double toKg(double display, String unit) =>
    unit == 'lb' ? display * _kgPerLb : display;

/// The suffix shown next to weights and volumes.
String unitLabel(String unit) => unit == 'lb' ? 'lb' : 'kg';
