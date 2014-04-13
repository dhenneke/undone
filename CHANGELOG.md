# Undone Changes

## 0.3.2-dev

- Added the `history`, `nextRedo` and `nextUndo` getters to `Schedule` and added
optional parameters `history` and `nextUndo` to its constructor.  These 
additions provide transparency into the internal history list of actions.  Use 
cases for this functionality include data-binding of a history list to a user 
inferface element and serialization of a history list between sessions.

## 0.3.1

- Deployed the `nudge` example to `gh-pages` and link to it from the `README`.

## 0.3.0

- Added an optional `context` to `Action` that allows user-defined data to be
attached to an action as an alternative to defining a new type of action.
- Changed the return type of the `Do` and `Undo` typedefs to be `dynamic` and
removed the `DoAsync` and `UndoAsync` typedefs.
- Removed the `new Action.async` constructor; the `new Action` constructor now
wraps all `Do` and `Undo` function calls using `new Future.sync` to support
both synchronous and asynchronous `Do` and `Undo` functions.
- Updated API documentation generation to use the new `docgen` tool.

## 0.2.15

- Changed the way validation errors at the start of `Schedule.call` are treated
such that they no longer affect the state of the schedule;  They are completed
as error to the caller with a stack trace, but they no longer modify the state 
of the schedule.
- Added a stack trace to transaction error continuations; this is equal to the
`TransactionError.causeStackTrace`.

## 0.2.14

- Fixed a bug in guarded action error completion that was introduced in the 
previous 0.2.13 release.

## 0.2.13

- Updated for the Dart 1.0 release.
- Added an optional `timeout` to `Action` objects and if it is non-null then 
guard all calls to do or undo the action with a timer.

## 0.2.12

- Added handling of `StackTrace` objects for errors encountered in a schedule:
	- All logged errors now include the stack trace, if any.
	- All action error continuations now receive the stack trace, if any.
	- When a schedule is in STATE_ERROR the `stackTrace` getter may be used to
	access the stack trace associated with the `error`, if any.	

## 0.2.11

- Updated to SDK 0.8.10_r29803.

## 0.2.10

- Updated to SDK 0.8.7_r29341.

## 0.2.9

- Updated to SDK 0.7.6_r28108.
- Added an `isIdle` getter to the `Schedule` and renamed the `busy` getter to 
`isBusy`; the new getter `isIdle` is for convenience and is equal to `!isBusy`.

## 0.2.8

- Updated to SDK 0.7.1_r27025.
- Added support for non-undoable actions.  An undo function is now an optional 
argument when constructing an action, and if it is `null` then the action's 
`canUndo` field will be false.  Non-undoable actions may be executed on a 
schedule in the same manner as undoable actions, and the order of their
execution is guaranteed.  However, the non-undoable action is not preserved in 
the history list (undo stack) and does not affect the state of the schedule in 
any way.

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
