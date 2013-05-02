# Undone Changes

## 0.2.1-dev

- Updated to SDK 0.5.1_r22072.

## 0.2.0

- Updated to SDK 0.5.0_r21823.

## 0.1.8

- Updated to SDK 0.4.7_r21548.

## 0.1.7

- Updated to SDK 0.4.4_r20810.
- Switched to using `assert` for dead code removal of logging code instead of a
`const bool`; the old mechanism required users to modify the library code to
enable logging, which was not ideal.  Now, logging will be enabled in 'checked'
mode and it will be stripped in 'production' mode.

## 0.1.6

- Changed the type of `Schedule.states` to `Stream<String>` and states are now
enumerated as `static const String`.

## 0.1.5

- Added logging code to the library; default disabled for dead code elimination. 
- Fixed a number of bugs.
- Removed the Timer-based `wait` utility function from the tests.

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
