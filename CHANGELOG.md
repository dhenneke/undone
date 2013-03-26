# Undone Changes

## 0.1.5-dev

- Fixed a possible race condition in `Schedule.to`.

## 0.1.4

- Added `timeoutMs` to `wait` test utility function; drone.io was hanging since
the new SDK (0.4.3_r20444) so this was added to try and catch the error but now
the error is not reproducing.  This should catch future test hangs.

## 0.1.3

- Updated to SDK 0.4.3_r20444.

## 0.1.2

- Added a link to an article in the README.

## 0.1.1

- Added `documentation` link to pubspec.

## 0.1.0

- README and dartdoc improvements.

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
