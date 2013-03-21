# Undone Changes

## 0.0.4

- README improvements.

## 0.0.3

- Updated to SDK 0.4.2_r20259.
- Moved `unittest` to `dev_dependencies`.
- Bug fix: continuations on undo(), redo(), to() are now called before we flush
  pending actions; this ensures continuations see things as a result of the
  operation they are chained to.

## 0.0.2

- Added `homepage` to pubspec.

## 0.0.1

- Initial release.
