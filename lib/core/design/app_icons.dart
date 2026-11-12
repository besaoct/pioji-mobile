import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The app's own icon set: 24 × 24 outline SVGs in `assets/icons/`, drawn
/// with a 1.75 stroke. Same look on Android and iOS.
enum AppIcons {
  // Modules
  home('home'),
  samples('samples'),
  offers('offers'),
  bids('bids'),
  batches('batches'),
  courier('courier'),
  contracts('contracts'),
  sales('sales'),
  exFactory('ex_factory'),
  more('more'),
  // Actions
  search('search'),
  add('add'),
  addCircle('add_circle'),
  edit('edit'),
  delete('delete'),
  share('share'),
  filter('filter'),
  close('close'),
  moreVert('more_vert'),
  camera('camera'),
  barcodeScan('barcode_scan'),
  personAdd('person_add'),
  people('people'),
  settings('settings'),
  signOut('sign_out'),
  // Navigation
  back('back'),
  arrowRight('arrow_right'),
  chevronLeft('chevron_left'),
  chevronRight('chevron_right'),
  chevronDown('chevron_down'),
  // Fields and documents
  calendar('calendar'),
  clock('clock'),
  document('document'),
  docSearch('doc_search'),
  eye('eye'),
  eyeOff('eye_off'),
  // Status
  check('check'),
  checkCircle('check_circle'),
  checkCircleFill('check_circle_fill'),
  circle('circle'),
  allDone('all_done'),
  approval('approval'),
  alert('alert'),
  offline('offline'),
  clear('clear');

  const AppIcons(this.file);
  final String file;

  String get asset => 'assets/icons/$file.svg';
}

/// Draws an [AppIcons] SVG. Like [Icon], the colour and size default to the
/// surrounding [IconTheme].
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size, this.color, this.semanticLabel});

  final AppIcons icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final svg = SvgPicture.asset(
      icon.asset,
      width: s,
      height: s,
      theme: SvgTheme(currentColor: color ?? theme.color ?? const Color(0xFF000000)),
      excludeFromSemantics: semanticLabel == null,
      semanticsLabel: semanticLabel,
    );
    // Like Icon: when a parent forces a bigger box (a 44 px button, a tile),
    // the glyph stays at [size] in the centre instead of stretching.
    return SizedBox.square(dimension: s, child: Center(child: SizedBox.square(dimension: s, child: svg)));
  }
}
