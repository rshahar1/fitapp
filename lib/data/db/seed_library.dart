/// The built-in exercise library (PRD §5.1).
class SeedExercise {
  const new(
    this.number,
    this.name,
    this.muscleGroup, {
    required this.perHand,
    required this.increment,
  });

  final int number;
  final String name;
  final String muscleGroup;
  final bool perHand;
  final double increment;

  /// Fixed UUID: `00000000-0000-4000-8000-` + 12-digit zero-padded hex.
  String get id =>
      '00000000-0000-4000-8000-${number.toRadixString(16).padLeft(12, '0')}';
}

const seedLibrary = <SeedExercise>[
  SeedExercise(
    1,
    'Barbell Bench Press',
    'Chest',
    perHand: false,
    increment: 2.5,
  ),
  SeedExercise(
    2,
    'Incline Dumbbell Bench Press',
    'Chest',
    perHand: true,
    increment: 2.5,
  ),
  SeedExercise(3, 'Cable Fly', 'Chest', perHand: false, increment: 2.5),
  SeedExercise(4, 'Barbell Back Squat', 'Legs', perHand: false, increment: 5),
  SeedExercise(5, 'Romanian Deadlift', 'Legs', perHand: false, increment: 5),
  SeedExercise(6, 'Leg Press', 'Legs', perHand: false, increment: 5),
  SeedExercise(7, 'Leg Curl', 'Legs', perHand: false, increment: 2.5),
  SeedExercise(8, 'Deadlift', 'Back', perHand: false, increment: 5),
  SeedExercise(9, 'Lat Pulldown', 'Back', perHand: false, increment: 2.5),
  SeedExercise(10, 'Seated Cable Row', 'Back', perHand: false, increment: 2.5),
  SeedExercise(11, 'Dumbbell Row', 'Back', perHand: true, increment: 2.5),
  SeedExercise(
    12,
    'Overhead Press',
    'Shoulders',
    perHand: false,
    increment: 2.5,
  ),
  SeedExercise(
    13,
    'Dumbbell Lateral Raise',
    'Shoulders',
    perHand: true,
    increment: 1,
  ),
  SeedExercise(14, 'Barbell Curl', 'Arms', perHand: false, increment: 2.5),
  SeedExercise(15, 'Dumbbell Hammer Curl', 'Arms', perHand: true, increment: 2),
  SeedExercise(16, 'Triceps Pushdown', 'Arms', perHand: false, increment: 2.5),
];

/// Display order of muscle groups in the picker.
const muscleGroups = ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms'];
