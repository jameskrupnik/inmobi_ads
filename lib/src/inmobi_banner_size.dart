import 'package:flutter/foundation.dart';

/// A banner size, in logical pixels.
///
/// InMobi does not enforce a fixed set the way AdMob does — a placement serves
/// whatever creative sizes it is configured for — but these three are the ones
/// worth asking for, and a mismatch between the widget's size and the
/// placement's is the usual reason a banner loads and renders blank.
@immutable
class InMobiBannerSize {
  /// Creates a custom size of [width] by [height] logical pixels.
  ///
  /// Match it to a creative size the placement is configured to serve, or the
  /// banner loads and renders blank.
  const InMobiBannerSize({required this.width, required this.height});

  /// 320×50. The standard phone banner.
  static const InMobiBannerSize banner =
      InMobiBannerSize(width: 320, height: 50);

  /// 728×90. Tablets only; it will not fit a phone in portrait.
  static const InMobiBannerSize leaderboard =
      InMobiBannerSize(width: 728, height: 90);

  /// 300×250. The in-feed rectangle.
  static const InMobiBannerSize mediumRectangle =
      InMobiBannerSize(width: 300, height: 250);

  /// The width, in logical pixels.
  final double width;

  /// The height, in logical pixels.
  final double height;

  @override
  bool operator ==(Object other) =>
      other is InMobiBannerSize &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'InMobiBannerSize(${width}x$height)';
}
