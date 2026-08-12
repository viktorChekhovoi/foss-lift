/// Stored English → the words on screen.
///
/// Several things in this app are stored in English and shown in whatever
/// language the app is rendering in: the muscle-group and equipment vocabulary,
/// which is also a wire format (a routine code sends an index into
/// `kMuscleGroups`, so translating the stored value would make the same code
/// mean different things on different phones), the names of the rows the app
/// shipped with, and the names of the shipped colour presets.
///
/// A seeded row keeps its English name in the `name` column like any other row
/// and carries a `seedKey` beside it. The key is what a screen renders from, so
/// the whole starter library follows a language switch rather than being frozen
/// at whatever the phone was set to on install day. A row you added yourself
/// has no key and keeps the name you gave it — and renaming a seeded routine or
/// training day clears the key, which is how "Chest & Tris" stays yours.
///
/// A shipped program has two such strings on one key: its name and the
/// description under it. The name follows the rule above; the description cannot,
/// because rewriting it must not cost the routine the key its name hangs on — see
/// [seededDescription].
library;

import '../data/database.dart';
import '../data/exercise_filter.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

export '../data/seed_keys.dart';

/// One exercise's words as a screen renders them — what the library search
/// matches on top of the English. See `ExerciseFilter.matches`.
ExerciseWords shownWords(AppLocalizations l10n, Exercise e) => (
      name: seededName(l10n, e.seedKey, e.name),
      muscleGroups: [
        for (final group in e.muscles.all) muscleGroupLabel(l10n, group),
      ],
      equipment: equipmentLabel(l10n, e.equipment),
    );

/// [name], unless [seedKey] names a row the app shipped — then its translation.
///
/// Falls back to [name] for an unknown key rather than showing the key, so a
/// starter movement retired from the map still reads as itself in history.
String seededName(AppLocalizations l10n, String? seedKey, String name) {
  if (seedKey == null) return name;
  return _seeded(l10n, seedKey) ?? name;
}

/// A routine's description as a screen shows it, or null when there is nothing
/// to show.
///
/// [description] is the column: canonical English on a copy of a shipped
/// program, and whatever was typed on anybody else's routine. Which of the two it
/// is cannot be read off [seedKey], because rewriting the description of a
/// shipped program does not — and should not — cost the routine the key its
/// *name* hangs on. So the text is compared against the program's own: the
/// shipped paragraph is translated, and one word of editing makes it yours, in
/// every language.
String? seededDescription(
  AppLocalizations l10n,
  String? seedKey,
  String? description,
) {
  if (description == null || description.trim().isEmpty) return null;
  if (seedKey == null) return description;
  if (starterDescriptionForSeedKey(seedKey) != description) return description;
  return _seededDescription(l10n, seedKey) ?? description;
}

/// A muscle group as stored (English, and an index in a routine code), in the
/// app's language. An unrecognised value is the user's own word and is shown
/// as it is — see the note on `kMuscleGroups`.
String muscleGroupLabel(AppLocalizations l10n, String stored) =>
    switch (stored) {
      'Chest' => l10n.muscleChest,
      'Back' => l10n.muscleBack,
      'Shoulders' => l10n.muscleShoulders,
      'Legs' => l10n.muscleLegs,
      'Arms' => l10n.muscleArms,
      'Core' => l10n.muscleCore,
      'Other' => l10n.muscleOther,
      'Cardio' => l10n.muscleCardio,
      _ => stored,
    };

/// The same, over the equipment kinds.
String equipmentLabel(AppLocalizations l10n, String stored) =>
    switch (stored) {
      'Barbell' => l10n.equipmentBarbell,
      'Dumbbell' => l10n.equipmentDumbbell,
      'Machine' => l10n.equipmentMachine,
      'Cable' => l10n.equipmentCable,
      'Bodyweight' => l10n.equipmentBodyweight,
      'Other' => l10n.equipmentOther,
      _ => stored,
    };

/// How a movement is loaded, in the app's language. The enum is stored as its
/// own name and travels in a routine code, so only the words shown move.
String weightTypeLabel(AppLocalizations l10n, WeightType type) =>
    switch (type) {
      WeightType.bar => l10n.weightTypeBar,
      WeightType.machine => l10n.weightTypeMachine,
      WeightType.dumbbell => l10n.weightTypeDumbbell,
      WeightType.none => l10n.weightTypeNone,
    };

/// The words on screen for [palette]'s name.
///
/// A shipped preset is named in the app's language, by the same rule the starter
/// exercise library follows: the English name in [AppPalette.name] is the stored
/// and transmitted one — it travels in an exported file and in a theme code —
/// and the id is what a screen looks its label up from. One of your own carries
/// the name you typed and keeps it.
String themeDisplayName(AppLocalizations l10n, AppPalette palette) =>
    switch (palette.id) {
      'ignition' => l10n.themePresetIgnition,
      'graphite' => l10n.themePresetGraphite,
      'solarized_dark' => l10n.themePresetSolarizedDark,
      'solarized_light' => l10n.themePresetSolarizedLight,
      'daylight' => l10n.themePresetDaylight,
      'paper' => l10n.themePresetPaper,
      'high_contrast' => l10n.themePresetHighContrastDark,
      'high_contrast_light' => l10n.themePresetHighContrastLight,
      _ => palette.name,
    };

String? _seeded(AppLocalizations l10n, String key) => switch (key) {
      'bench_press' => l10n.exerciseBenchPress,
      'incline_bench_press' => l10n.exerciseInclineBenchPress,
      'decline_bench_press' => l10n.exerciseDeclineBenchPress,
      'dumbbell_bench_press' => l10n.exerciseDumbbellBenchPress,
      'incline_db_press' => l10n.exerciseInclineDbPress,
      'dumbbell_fly' => l10n.exerciseDumbbellFly,
      'machine_chest_press' => l10n.exerciseMachineChestPress,
      'pec_deck' => l10n.exercisePecDeck,
      'cable_fly' => l10n.exerciseCableFly,
      'push_up' => l10n.exercisePushUp,
      'chest_dip' => l10n.exerciseChestDip,
      'deadlift' => l10n.exerciseDeadlift,
      'barbell_row' => l10n.exerciseBarbellRow,
      'barbell_shrug' => l10n.exerciseBarbellShrug,
      'dumbbell_row' => l10n.exerciseDumbbellRow,
      't_bar_row' => l10n.exerciseTBarRow,
      'chest_supported_row' => l10n.exerciseChestSupportedRow,
      'lat_pulldown' => l10n.exerciseLatPulldown,
      'seated_cable_row' => l10n.exerciseSeatedCableRow,
      'straight_arm_pulldown' => l10n.exerciseStraightArmPulldown,
      'face_pull' => l10n.exerciseFacePull,
      'pull_up' => l10n.exercisePullUp,
      'chin_up' => l10n.exerciseChinUp,
      'inverted_row' => l10n.exerciseInvertedRow,
      'back_extension' => l10n.exerciseBackExtension,
      'overhead_press' => l10n.exerciseOverheadPress,
      'push_press' => l10n.exercisePushPress,
      'upright_row' => l10n.exerciseUprightRow,
      'dumbbell_shoulder_press' => l10n.exerciseDumbbellShoulderPress,
      'arnold_press' => l10n.exerciseArnoldPress,
      'lateral_raise' => l10n.exerciseLateralRaise,
      'front_raise' => l10n.exerciseFrontRaise,
      'rear_delt_fly' => l10n.exerciseRearDeltFly,
      'machine_shoulder_press' => l10n.exerciseMachineShoulderPress,
      'reverse_pec_deck' => l10n.exerciseReversePecDeck,
      'cable_lateral_raise' => l10n.exerciseCableLateralRaise,
      'back_squat' => l10n.exerciseBackSquat,
      'front_squat' => l10n.exerciseFrontSquat,
      'sumo_deadlift' => l10n.exerciseSumoDeadlift,
      'romanian_deadlift' => l10n.exerciseRomanianDeadlift,
      'good_morning' => l10n.exerciseGoodMorning,
      'goblet_squat' => l10n.exerciseGobletSquat,
      'bulgarian_split_squat' => l10n.exerciseBulgarianSplitSquat,
      'walking_lunge' => l10n.exerciseWalkingLunge,
      'step_up' => l10n.exerciseStepUp,
      'leg_press' => l10n.exerciseLegPress,
      'hack_squat' => l10n.exerciseHackSquat,
      'leg_curl' => l10n.exerciseLegCurl,
      'leg_extension' => l10n.exerciseLegExtension,
      'calf_raise' => l10n.exerciseCalfRaise,
      'seated_calf_raise' => l10n.exerciseSeatedCalfRaise,
      'hip_thrust' => l10n.exerciseHipThrust,
      'glute_bridge' => l10n.exerciseGluteBridge,
      'hip_abduction' => l10n.exerciseHipAbduction,
      'cable_pull_through' => l10n.exerciseCablePullThrough,
      'glute_kickback' => l10n.exerciseGluteKickback,
      'barbell_curl' => l10n.exerciseBarbellCurl,
      'preacher_curl' => l10n.exercisePreacherCurl,
      'close_grip_bench_press' => l10n.exerciseCloseGripBenchPress,
      'skull_crusher' => l10n.exerciseSkullCrusher,
      'dumbbell_curl' => l10n.exerciseDumbbellCurl,
      'hammer_curl' => l10n.exerciseHammerCurl,
      'incline_dumbbell_curl' => l10n.exerciseInclineDumbbellCurl,
      'triceps_pushdown' => l10n.exerciseTricepsPushdown,
      'overhead_cable_extension' => l10n.exerciseOverheadCableExtension,
      'cable_curl' => l10n.exerciseCableCurl,
      'triceps_dip' => l10n.exerciseTricepsDip,
      'reverse_curl' => l10n.exerciseReverseCurl,
      'wrist_curl' => l10n.exerciseWristCurl,
      'reverse_wrist_curl' => l10n.exerciseReverseWristCurl,
      'farmers_carry' => l10n.exerciseFarmersCarry,
      'dead_hang' => l10n.exerciseDeadHang,
      'cable_crunch' => l10n.exerciseCableCrunch,
      'pallof_press' => l10n.exercisePallofPress,
      'machine_crunch' => l10n.exerciseMachineCrunch,
      'ab_wheel_rollout' => l10n.exerciseAbWheelRollout,
      'plank' => l10n.exercisePlank,
      'side_plank' => l10n.exerciseSidePlank,
      'hollow_hold' => l10n.exerciseHollowHold,
      'hanging_leg_raise' => l10n.exerciseHangingLegRaise,
      'crunch' => l10n.exerciseCrunch,
      'reverse_crunch' => l10n.exerciseReverseCrunch,
      'russian_twist' => l10n.exerciseRussianTwist,
      'dead_bug' => l10n.exerciseDeadBug,
      'power_clean' => l10n.exercisePowerClean,
      'kettlebell_swing' => l10n.exerciseKettlebellSwing,
      'turkish_get_up' => l10n.exerciseTurkishGetUp,
      'air_squat' => l10n.exerciseAirSquat,
      'bodyweight_lunge' => l10n.exerciseBodyweightLunge,
      'pike_push_up' => l10n.exercisePikePushUp,
      'diamond_push_up' => l10n.exerciseDiamondPushUp,
      'wide_push_up' => l10n.exerciseWidePushUp,
      'decline_push_up' => l10n.exerciseDeclinePushUp,
      'nordic_curl' => l10n.exerciseNordicCurl,
      'single_leg_glute_bridge' => l10n.exerciseSingleLegGluteBridge,
      'wall_sit' => l10n.exerciseWallSit,
      'superman_hold' => l10n.exerciseSupermanHold,
      'bird_dog' => l10n.exerciseBirdDog,
      'sit_up' => l10n.exerciseSitUp,
      'burpee' => l10n.exerciseBurpee,
      'mountain_climber' => l10n.exerciseMountainClimber,
      'high_knees' => l10n.exerciseHighKnees,
      'jumping_jack' => l10n.exerciseJumpingJack,
      'jump_squat' => l10n.exerciseJumpSquat,
      'box_jump' => l10n.exerciseBoxJump,
      'skater_jump' => l10n.exerciseSkaterJump,
      'bear_crawl' => l10n.exerciseBearCrawl,
      'sprint' => l10n.exerciseSprint,
      'jump_rope' => l10n.exerciseJumpRope,
      'battle_rope' => l10n.exerciseBattleRope,
      'shadow_boxing' => l10n.exerciseShadowBoxing,
      'treadmill' => l10n.exerciseTreadmill,
      'elliptical' => l10n.exerciseElliptical,
      'stationary_bike' => l10n.exerciseStationaryBike,
      'recumbent_bike' => l10n.exerciseRecumbentBike,
      'rowing_machine' => l10n.exerciseRowingMachine,
      'stair_climber' => l10n.exerciseStairClimber,
      'air_bike' => l10n.exerciseAirBike,
      'ski_erg' => l10n.exerciseSkiErg,
      'arc_trainer' => l10n.exerciseArcTrainer,
      'jacobs_ladder' => l10n.exerciseJacobsLadder,
      'dumbbell_thruster' => l10n.exerciseDumbbellThruster,
      'dumbbell_clean_and_press' => l10n.exerciseDumbbellCleanAndPress,
      'dumbbell_snatch' => l10n.exerciseDumbbellSnatch,
      'dumbbell_romanian_deadlift' => l10n.exerciseDumbbellRomanianDeadlift,
      'dumbbell_deadlift' => l10n.exerciseDumbbellDeadlift,
      'dumbbell_front_squat' => l10n.exerciseDumbbellFrontSquat,
      'dumbbell_lunge' => l10n.exerciseDumbbellLunge,
      'dumbbell_lateral_lunge' => l10n.exerciseDumbbellLateralLunge,
      'dumbbell_floor_press' => l10n.exerciseDumbbellFloorPress,
      'renegade_row' => l10n.exerciseRenegadeRow,
      'dumbbell_pullover' => l10n.exerciseDumbbellPullover,
      'dumbbell_push_press' => l10n.exerciseDumbbellPushPress,
      'push_pull_legs' => l10n.seedRoutinePushPullLegs,
      'upper_lower' => l10n.seedRoutineUpperLower,
      'starting_strength' => l10n.seedRoutineStartingStrength,
      'stronglifts_5x5' => l10n.seedRoutineStrongLifts5x5,
      'full_body_3x' => l10n.seedRoutineFullBody3x,
      'two_day_full_body' => l10n.seedRoutineTwoDayFullBody,
      'bodyweight_basics' => l10n.seedRoutineBodyweightBasics,
      'dumbbell_full_body' => l10n.seedRoutineDumbbellFullBody,
      'interval_conditioning' => l10n.seedRoutineIntervalConditioning,
      'workout_a' => l10n.seedDayWorkoutA,
      'workout_b' => l10n.seedDayWorkoutB,
      'workout_c' => l10n.seedDayWorkoutC,
      'push' => l10n.seedDayPush,
      'pull' => l10n.seedDayPull,
      'legs' => l10n.seedDayLegs,
      'upper_1' => l10n.seedDayUpper1,
      'lower_1' => l10n.seedDayLower1,
      'upper_2' => l10n.seedDayUpper2,
      'lower_2' => l10n.seedDayLower2,
      'olympic_bar' => l10n.seedBarOlympicBar,
      'womens_olympic_bar' => l10n.seedBarWomensOlympicBar,
      'ez_curl_bar' => l10n.seedBarEzCurlBar,
      'trap_bar' => l10n.seedBarTrapBar,
      'safety_squat_bar' => l10n.seedBarSafetySquatBar,
      'smith_carriage' => l10n.seedBarSmithCarriage,
      _ => null,
    };

/// The description shipped with the program keyed [key], in the app's language.
///
/// A separate table from [_seeded] because a program has two shipped strings and
/// one key: the name and the paragraph under it are translated independently, and
/// a published title left in English still has a description worth reading.
String? _seededDescription(AppLocalizations l10n, String key) => switch (key) {
      'push_pull_legs' => l10n.seedRoutineDescPushPullLegs,
      'upper_lower' => l10n.seedRoutineDescUpperLower,
      'starting_strength' => l10n.seedRoutineDescStartingStrength,
      'stronglifts_5x5' => l10n.seedRoutineDescStrongLifts5x5,
      'full_body_3x' => l10n.seedRoutineDescFullBody3x,
      'two_day_full_body' => l10n.seedRoutineDescTwoDayFullBody,
      'bodyweight_basics' => l10n.seedRoutineDescBodyweightBasics,
      'dumbbell_full_body' => l10n.seedRoutineDescDumbbellFullBody,
      'interval_conditioning' => l10n.seedRoutineDescIntervalConditioning,
      _ => null,
    };
