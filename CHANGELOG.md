# Changelog

## [1.2.0] — 2026-11-17

### Added
- Due countdown on the card's third line: names the course/kind and time left ("Math-3: 2d left", "Math-3: 6h left") — hours count down inside the item's day when a course is chosen, never below "1d left" otherwise (b02a170)
- Multiple coursework aggregates into "{n} tasks, {closest course}: {time left}" on both the app Now card and home-screen widget (b02a170)
- Ct.course is now optional — old JSON without a course still parses (b02a170)

### Changed
- Widget type dial: all texts 4% smaller, line height 2% less (311792b)
- Card title shows "Untitled" fallback when a course is missing (2bcebd6)
- Widget spacer uses a TextView so MIUI's inflater doesn't reject it (81d0bed)
- Headline runs over the accent panel with a sharp white shadow (493581e)

[1.2.0]: https://github.com/mahtamun-hoque-fahim/clasSync/compare/v1.1.0...v1.2.0

[1.1.0]: https://github.com/mahtamun-hoque-fahim/clasSync/compare/v1.0.0...v1.1.0
