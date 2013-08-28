# Undone Changes

## 0.2.8-dev

## 0.2.7

- Updated to SDK 0.6.21_r26639.

## 0.2.6

- Updated to SDK 0.6.19_r26297.
- Added the `bench` package to `dev_dependencies` to run the unit tests.
- Removed the `undone.mirrors` library as I believe it only added confusion; if
you have a need for the removed `SetFieldAction` please open an issue in the
tracker.

## 0.2.5

- Updated to SDK 0.5.20.2_r24160.

## 0.2.4

- Updated to SDK 0.5.13_r23552.
- Switched `states` stream to use the new `StreamController.broadcast` that was
re-introduced in this SDK version.  With this change the `Schedule` is no longer
responsible for checking the paused state (a broadcast stream controller is 
never considered paused) before adding events to the stream; each subscription
will buffer events itself when paused.
- Added `Future<String> wait(String state)` method to `Schedule` and updated the 
tests to use this instead of their former utility function equivalent; the 
motivation for this is that I have other use cases for this function now outside
of testing.

## 0.2.3

- Updated to SDK 0.5.11_r23200.
- Added `mirrors.dart` library with a `SetField` action; this is a separate 
library so that users conciously import it and its dependency on `dart:mirrors`.

## 0.2.2

- Updated to SDK 0.5.7_r22611.
- Handle the change to Completer behavior; they are now completed asynchronously
by default.  A schedule will now flush pending actions at the end of the series
of asynchronous events trigerred by its completers, making it more bulletproof.

## 0.2.1

- Updated to SDK 0.5.3_r22223.
- Avoid streaming `states` events unless there is a listener and the stream is 
not paused.  This avoids potential memory leaks that might arise with buffered
events.

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
