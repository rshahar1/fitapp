import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The app's only icon set (feature 034): Material Symbols **Sharp**, drawn
/// heavy by the theme (`IconThemeData.weight`), with square corners and
/// terminals. Widgets use these names, never the stock Material set.
abstract final class AppIcons {
  // Actions.
  static const IconData add = Symbols.add_sharp;
  static const IconData addBox = Symbols.add_box_sharp;
  static const IconData remove = Symbols.remove_sharp;
  static const IconData check = Symbols.check_sharp;
  static const IconData close = Symbols.close_sharp;
  static const IconData edit = Symbols.edit_sharp;
  static const IconData delete = Symbols.delete_sharp;
  static const IconData search = Symbols.search_sharp;
  static const IconData searchOff = Symbols.search_off_sharp;
  static const IconData share = Symbols.share_sharp;
  static const IconData replay = Symbols.replay_sharp;
  static const IconData more = Symbols.more_vert_sharp;
  static const IconData dragHandle = Symbols.drag_handle_sharp;
  static const IconData login = Symbols.login_sharp;
  static const IconData lock = Symbols.lock_sharp;
  static const IconData lockOpen = Symbols.lock_open_sharp;

  // Navigation.
  static const IconData back = Symbols.arrow_back_sharp;
  static const IconData chevronLeft = Symbols.chevron_left_sharp;
  static const IconData chevronRight = Symbols.chevron_right_sharp;
  static const IconData calendar = Symbols.calendar_month_sharp;
  static const IconData history = Symbols.history_sharp;
  static const IconData chart = Symbols.show_chart_sharp;
  static const IconData list = Symbols.view_list_sharp;
  static const IconData listAlt = Symbols.list_alt_sharp;
  static const IconData person = Symbols.person_sharp;
  static const IconData settings = Symbols.settings_sharp;
  static const IconData layers = Symbols.layers_sharp;

  // Playback and timing.
  static const IconData play = Symbols.play_arrow_sharp;
  static const IconData pause = Symbols.pause_sharp;
  static const IconData timer = Symbols.timer_sharp;
  static const IconData flag = Symbols.flag_sharp;

  // Status.
  static const IconData info = Symbols.info_sharp;
  static const IconData error = Symbols.error_sharp;
  static const IconData science = Symbols.science_sharp;
  static const IconData cable = Symbols.cable_sharp;

  // Location.
  static const IconData gpsFixed = Symbols.gps_fixed_sharp;
  static const IconData gpsSearching = Symbols.gps_not_fixed_sharp;
  static const IconData myLocation = Symbols.my_location_sharp;
  static const IconData locationOn = Symbols.location_on_sharp;
  static const IconData locationOff = Symbols.location_off_sharp;
  static const IconData locationDisabled = Symbols.location_disabled_sharp;

  // Activities.
  static const IconData gym = Symbols.fitness_center_sharp;
  static const IconData cycling = Symbols.directions_bike_sharp;
  static const IconData running = Symbols.directions_run_sharp;
  static const IconData snowboarding = Symbols.snowboarding_sharp;
  static const IconData skiing = Symbols.downhill_skiing_sharp;
  static const IconData pilates = Symbols.self_improvement_sharp;
  static const IconData sport = Symbols.sports_sharp;
}
