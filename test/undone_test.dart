@TestGroup(description: 'Undone')
library undone.test;

import 'dart:async';
import 'dart:math' as math;
import 'package:bench/bench.dart';
import 'package:logging/logging.dart';
import 'package:undone/undone.dart';
import 'package:unittest/unittest.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord
    .where((record) => record.loggerName == 'undone')
    .listen((record) => print('${record.message}'));  
  reflectTests();
}

// -----------------------------------------------------------------------------
// Setup
// -----------------------------------------------------------------------------

@Teardown
teardown() => schedule.wait(Schedule.STATE_IDLE).then((_) => schedule.clear());

// Top-level functions used across test cases; stateless.
Do increment = (a) { a['oldValue'] = a['val']; return ++a['val']; };
Undo decrement = (a, _) => --a['val'];
Undo restore = (a, _) => a['val'] = a['oldValue'];
Do square = (a) => a['val'] = a['val'] * a['val'];  
Undo squareRoot = (a, _) => a['val'] = math.sqrt(a['val']);

Do incrementAsync = (a) => 
    new Future.delayed(const Duration(milliseconds: 4), () => increment(a));
Undo decrementAsync = (a, _) => 
    new Future.delayed(const Duration(milliseconds: 5), () => decrement(a, _));
Undo restoreAsync = (a, _) => 
    new Future.delayed(const Duration(milliseconds: 2), () => restore(a, _));
Do squareAsync = (a) => 
    new Future.delayed(const Duration(milliseconds: 3), () => square(a));
Undo squareRootAsync = (a, _) => 
    new Future.delayed(const Duration(milliseconds: 5), () => squareRoot(a, _));

class HasFields {
  int i = 7;
}

// -----------------------------------------------------------------------------
// Basic
// -----------------------------------------------------------------------------

@Test('Test the initial state of a freshly constructed schedule.')
void testScheduleInitialState() {
  var schedule = new Schedule();
  expect(schedule.isBusy, isFalse);
  expect(schedule.isIdle, isTrue);
  expect(schedule.canClear, isTrue);
  expect(schedule.canRedo, isFalse);  
  expect(schedule.canUndo, isFalse);  
  expect(schedule.hasError, isFalse);  
  expect(schedule.error, isNull);
  expect(schedule.stackTrace, isNull);
  expect(schedule.history, isEmpty);
  expect(schedule.nextRedo, equals(-1));
  expect(schedule.nextUndo, equals(-1));
}

@Test('Test the construction of a schedule with existing history')
void testScheduleConstructorWithHistory() {
  var action = new Action(7, (x) => x + 1, (x, y) => x = y);
  var history = [action];
  var schedule = new Schedule(history);  
  expect(schedule.isBusy, isFalse);
  expect(schedule.isIdle, isTrue);
  expect(schedule.canClear, isTrue);
  expect(schedule.canRedo, isFalse);  
  expect(schedule.canUndo, isTrue);  
  expect(schedule.hasError, isFalse);  
  expect(schedule.error, isNull);
  expect(schedule.stackTrace, isNull);
  expect(schedule.history, isNot(same(history)));
  expect(schedule.history.length, equals(1));
  expect(schedule.history[0], equals(action));
  expect(schedule.nextRedo, equals(-1));
  expect(schedule.nextUndo, equals(0));
}

@Test('Test that action constructors succeed when given valid arguments.')
void testActionConstructor() {
  var action = new Action(7, (x) => x + 1, (x, y) => x = y);
  var actionAsync = new Action(11, 
      (x) => new Future.delayed(const Duration(milliseconds: 5), () => x - 1), 
      (x, y) => 
          new Future.delayed(const Duration(milliseconds: 3), () => x = y));
  expect(action.canUndo, isTrue);
  expect(actionAsync.canUndo, isTrue);
}

@Test('Test the construction of a non-undoable action')
void testActionConstructorNotUndoable() {
  var action = new Action(7, (x) => x + 1, null);
  var actionAsync = new Action(11, (x) => new Future(() => x - 1), null);
  expect(action.canUndo, isFalse);
  expect(actionAsync.canUndo, isFalse);
}

@Test('Test that action constructors throw ArgumentError on null functions.')
void testActionConstructorNullThrows() {
  expect(() => new Action(7, null, (x, y) => x = y), 
      throwsA(const isInstanceOf<ArgumentError>()));
  expect(() => new Action(11, null, 
      (x, y) =>new Future(() => x = y)), 
      throwsA(const isInstanceOf<ArgumentError>()));
}

@Test('Test that an action computes as expected.')
void testAction() {
  var action = new Action(14, (x) => x + 1, (x, y) => x - 1);
  action().then(expectAsync((result) {
    expect(result, equals(15));
    expect(schedule.history.length, equals(1));
    expect(schedule.history[0], equals(action));
    expect(schedule.nextUndo, equals(0));
    expect(schedule.nextRedo, equals(-1));
  }));
}

@Test('Test that an async action computes as expected.')
void testActionAsync() {
  var action = new Action(11, 
      (x) => new Future.delayed(const Duration(milliseconds: 5), () => x - 1), 
      (x, y) => 
          new Future.delayed(const Duration(milliseconds: 3), () => x = y));
  action().then(expectAsync((result) {
    expect(result, equals(10));
    expect(schedule.history.length, equals(1));
    expect(schedule.history[0], equals(action));
    expect(schedule.nextUndo, equals(0));
    expect(schedule.nextRedo, equals(-1));
  }));
}

@Test('Test that an error thrown by an action is handled as expected.')
void testActionThrows() {
  var schedule = new Schedule();
  var action = new Action(14, (x) => throw 'snarf', (x, y) => true);  
  schedule(action)
    .catchError(expectAsync((e, stackTrace) { 
      expect(e, equals('snarf'));
      expect(stackTrace, isNotNull);
      expect(schedule.hasError, isTrue);
      expect(schedule.error, equals(e));
      expect(schedule.stackTrace, equals(stackTrace));
      expect(schedule.history.length, equals(1));
   }));
}

@Test('Test that a non-undoable action computes as expected.')
void testActionNonUndoable() {
  var action = new Action(14, (x) => x + 1, null);
  action()
    .then(expectAsync((result) {
      expect(result, equals(15));
      expect(schedule.canUndo, isFalse);
      expect(schedule.canRedo, isFalse);
      expect(schedule.hasError, isFalse);
      expect(schedule.history, isEmpty);
      expect(schedule.nextUndo, equals(-1));
      expect(schedule.nextRedo, equals(-1));
    }));
}

@Test('Test that an attempt to schedule the same action twice throws error.')
void testScheduleSameActionTwiceThrows() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  var action = new Action(map, increment, decrement);  
  schedule(action)
    .then(expectAsync((result) => expect(result, equals(43))))
    .then((_) => schedule(action))
    .catchError(expectAsync((e, stackTrace) {
      expect(e, isArgumentError);
      expect(stackTrace, isNotNull);
      expect(schedule.hasError, isFalse);
      expect(schedule.error, isNull);
      expect(schedule.stackTrace, isNull);
      expect(schedule.history.length, equals(1));
    }));
}

@Test('Test that an action call throws StateError if the Schedule hasError.')
void testScheduleHasErrorActionThrows() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  var action1 = new Action(map, (x) => throw 'snarf', decrement);
  var action2 = new Action(map, increment, decrement);
  
  // The first action should throw and put the schedule in an error state.
  schedule(action1)
    .catchError((e, stackTrace) {  
      expect(e, equals('snarf'));
      expect(schedule.hasError, isTrue);
      expect(schedule.error, equals(e));
      expect(schedule.stackTrace, isNotNull);
      expect(schedule.stackTrace, equals(stackTrace));
    })
    // The second action should cause a StateError to be thrown.
    .then((_) => schedule(action2))
    .catchError(expectAsync((e, stackTrace) {   
      expect(e, isStateError);
      expect(stackTrace, isNotNull);
      expect(schedule.error, isNot(equals(e)));
      expect(schedule.stackTrace, isNot(equals(stackTrace)));
    }));
}

@Test('Test that an action call is added to the user-provided history list.')
void testScheduleUserProvidedHistory() {
  var action = new Action(14, (x) => x + 1, (x, y) => x - 1);
  var history = [];
  var schedule = new Schedule(history);
  schedule(action).then(expectAsync((result) {
    expect(result, equals(15));
    expect(history.length, equals(1));
    expect(history[0], equals(action)); 
    expect(schedule.history.length, equals(1));
    expect(schedule.history[0], equals(action));    
    expect(schedule.nextUndo, equals(0));
    expect(schedule.nextRedo, equals(-1));
  }));
}

@Test('Test the successful completion of an undo operation.')
void testUndo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  var action = new Action(map, increment, decrement);
  schedule(action)
    .then((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
      expect(schedule.history.length, equals(1));
      expect(schedule.history[0], equals(action));
      expect(schedule.nextRedo, equals(-1));
      expect(schedule.nextUndo, equals(0));
    })
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) => schedule.undo())
    .then(expectAsync((success) {
      expect(success, isTrue);
      expect(map['val'], equals(42));
      expect(schedule.history.length, equals(1));
      expect(schedule.history[0], equals(action));
      expect(schedule.nextRedo, equals(0));
      expect(schedule.nextUndo, equals(-1));
    }));
}

@Test('Test that an error thrown by an action undo is handled as expected.')
void testUndoThrows() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  var action = new Action(map, increment, (a, r) => throw 'uh-oh');
  schedule(action)
    .then((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    })
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) => schedule.undo())
    .catchError(expectAsync((e, stackTrace) { 
      expect(e, equals('uh-oh'));
      expect(stackTrace, isNotNull);
      expect(schedule.hasError, isTrue);
      expect(schedule.error, e);
      expect(schedule.stackTrace, stackTrace);
      expect(schedule.history.length, equals(1));
      expect(schedule.history[0], equals(action));
      expect(schedule.nextRedo, equals(0));
      expect(schedule.nextUndo, equals(-1));
   }));
}

@Test('Test the successful completion of an redo operation.')
void testRedo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  var action = new Action(map, increment, decrement);
  schedule(action)
    .then((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
      expect(schedule.history.length, equals(1));
      expect(schedule.history[0], equals(action));
      expect(schedule.nextRedo, equals(-1));
      expect(schedule.nextUndo, equals(0));
    })
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) => schedule.undo())
    .then((success) {
      expect(success, isTrue);
      expect(map['val'], equals(42));
      expect(schedule.history.length, equals(1));
      expect(schedule.history[0], equals(action));
      expect(schedule.nextRedo, equals(0));
      expect(schedule.nextUndo, equals(-1));
    })
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) => schedule.redo())
    .then(expectAsync((success) {
      expect(success, isTrue);
      expect(map['val'], equals(43));
      expect(schedule.history.length, equals(1));
      expect(schedule.history[0], equals(action));
      expect(schedule.nextRedo, equals(-1));
      expect(schedule.nextUndo, equals(0));
    }));
}

@Test('Test that an error thrown by an action redo is handled as expected.')
void testRedoThrows() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  int doCount = 0;
  var action = new Action(map, 
      (a) {
        if (doCount++ == 1) throw 'overdone';
        return ++a['val'];
      }, decrement);
  schedule(action)
    .then((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    })
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) => schedule.undo())
    .then((success) {
      expect(success, isTrue);
      expect(map['val'], equals(42));
    })
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) => schedule.redo())
    .catchError(expectAsync((e, stackTrace) { 
      expect(e, equals('overdone'));
      expect(stackTrace, isNotNull);
      expect(schedule.hasError, isTrue);
      expect(schedule.error, e);
      expect(schedule.stackTrace, stackTrace);
   }));
}

@Test('Test that an undo operation returns false if canUndo is false.')
void testUndoEmptyScheduleReturnsFalse() {
  new Schedule()
    .undo().then(expectAsync((success) => expect(success, isFalse)));
}

@Test('Test that a redo operation returns false if canRedo is false.')
void testRedoEmptyScheduleReturnsFalse() {
  new Schedule()
    .redo().then(expectAsync((success) => expect(success, isFalse)));
}

@Test('Test the successful completion of a to operation.')
void testTo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action(map, square, squareRoot);
  var action3 = new Action(map, increment, restore);
  
  schedule(action1)
    .then((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    })
    .then((_) => schedule(action2))
    .then((result) {
      expect(result, equals(1849));
      expect(map['val'], equals(1849));
    })
    .then((_) => schedule(action3))
    .then((result) {
      expect(result, equals(1850));
      expect(map['val'], equals(1850));
      expect(schedule.history.length, equals(3));
      expect(schedule.history[0], equals(action1));
      expect(schedule.history[1], equals(action2));
      expect(schedule.history[2], equals(action3));
      expect(schedule.nextRedo, equals(-1));
      expect(schedule.nextUndo, equals(2));
    })
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) => schedule.to(action1))
    .then((success) {
      expect(success, isTrue);
      expect(map['val'], equals(43));
      expect(schedule.nextRedo, equals(1));
      expect(schedule.nextUndo, equals(0));
    })    
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) => schedule.to(action3))
    .then(expectAsync((success) {
      expect(success, isTrue);
      expect(map['val'], equals(1850));
      expect(schedule.nextRedo, equals(-1));
      expect(schedule.nextUndo, equals(2));
    }));
}

@Test('Test the successful clear of a schedule.')
void testClear() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action(map, square, squareRoot);
  var action3 = new Action(map, increment, restore);
  
  schedule(action1);
  schedule(action2);
  schedule(action3)
    .then((result) {
      expect(result, equals(1850));
      expect(map['val'], equals(1850));
    })
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then(expectAsync((_) {
      expect(schedule.canClear, isTrue);
      expect(schedule.clear(), isTrue);
      expect(schedule.canClear, isTrue);
      expect(schedule.canUndo, isFalse);
      expect(schedule.canRedo, isFalse);
      expect(schedule.hasError, isFalse);
      expect(schedule.error, isNull);
      expect(schedule.stackTrace, isNull);
      expect(schedule.history, isEmpty);
      expect(schedule.nextRedo, equals(-1));
      expect(schedule.nextUndo, equals(-1));
    }));
}

@Test()
@ExpectError(isTimeoutException)
testActionTimeoutNeverComplete() {
  var schedule = new Schedule();
  var action = new Action(42, (_) => new Completer().future, null, 
      timeout: const Duration(milliseconds: 100));
  return schedule(action);
}

@Test()
@ExpectError(isTimeoutException)
testActionTimeoutThenComplete() {
  var schedule = new Schedule();
  var action = new Action(42, 
      (_) => new Future.delayed(const Duration(milliseconds: 200)),
      null, timeout: const Duration(milliseconds: 100));
  return schedule(action);
}

@Test()
@ExpectError(isTimeoutException)
testUndoTimeout() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  var action = new Action(map, incrementAsync, (_,__) => new Completer().future,
      timeout: const Duration(milliseconds: 100));
  return schedule(action)
    .then((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    })
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) => schedule.undo());
}

@Test()
testActionStringContext() {
  var action = new Action(14, (x) => x + 1, (x, y) => x - 1, context: 'snarf');
  expect(action.context, equals('snarf'));
  expect(action.toString(), equals('action(snarf)'));
  // Verify that the `context` has no impact on the execution.
  action().then(expectAsync((result) => expect(result, equals(15))));
}

@Test()
testActionIntContext() {
  var action = new Action(14, (x) => x + 1, (x, y) => x - 1, context: 42);
  expect(action.context, equals(42));
  expect(action.toString(), equals('action(42)'));
  // Verify that the `context` has no impact on the execution.
  action().then(expectAsync((result) => expect(result, equals(15))));
}

// -----------------------------------------------------------------------------
// Concurrent
// -----------------------------------------------------------------------------

@Test('Test the expected order of two concurrent actions.')
void testActionDuringAction() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, incrementAsync, decrementAsync);
  var action2 = new Action(map, square, squareRoot);
  
  // Schedule an async action that takes more than 1 tick.
  schedule(action1)
    .then(expectAsync((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    }));
  
  // Schedule a synchronous action that we expect to be done after the first.
  schedule(action2)
    .then(expectAsync((result) {
      expect(result, equals(1849));
      expect(map['val'], equals(1849));
    }));
}

@Test('Test that an error thrown by a pending action does not affect other.')
void testActionThrowsDuringAction() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, incrementAsync, decrementAsync);
  var action2 = new Action(map, (a) => throw 'crowbar', squareRoot);
  
  // Schedule an async action that takes more than 1 tick.
  schedule(action1)
    .then(expectAsync((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    }));
  
  var _stackTrace;
  // Schedule a synchronous action that we expect to be called after the first
  // completes, so we expect the thrown error to have no affect on the first.
  schedule(action2)
    .catchError(expectAsync((e, stackTrace) {    
      expect(e, equals('crowbar'));   
      expect(stackTrace, isNotNull);
      _stackTrace = stackTrace;
    }))
    .then((_) => schedule.wait(Schedule.STATE_ERROR))
    .then(expectAsync((_) {
      expect(schedule.hasError, isTrue);
      expect(schedule.error, equals('crowbar'));
      expect(schedule.stackTrace, equals(_stackTrace));
    }));
}

@Test('Test the expected order of multiple concurrent actions.')
void testMultipleActionsDuringAction() {  
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, incrementAsync, decrementAsync);
  var action2 = new Action(map, square, squareRoot);
  var action3 = new Action(map, squareAsync, squareRootAsync);
  var action4 = new Action(map, increment, restore);
  
  schedule(action1)
    .then(expectAsync((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    }));
  
  schedule(action2)
    .then(expectAsync((result) {
      expect(result, equals(1849));
      expect(map['val'], equals(1849));
    }));
  
  schedule(action3)
    .then(expectAsync((result) {
      expect(result, equals(3418801));
      expect(map['val'], equals(3418801));
    })); 
  
  schedule(action4)
    .then(expectAsync((result) {
      expect(result, equals(3418802));
      expect(map['val'], equals(3418802));
    }));  
}

@Test('Test that an attempt to defer the same action twice throws error.')
void testDeferSameActionTwiceThrows() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, incrementAsync, decrementAsync);
  var action2 = new Action(map, square, squareRoot);
  
  // Schedule an async action that takes more than 1 tick.
  schedule(action1)
    .then(expectAsync((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    }));
  
  // Schedule another action 2 times, expecting error on the second schedule.
  
  schedule(action2)
    .then(expectAsync((result) {
      expect(result, equals(1849));
      expect(map['val'], equals(1849));
    }));
  
  schedule(action2)
    .catchError(expectAsync((e, stackTrace) {
      expect(e, isArgumentError);
      expect(stackTrace, isNotNull);
      expect(schedule.hasError, isFalse);
      expect(schedule.error, isNull);
      expect(schedule.stackTrace, isNull);
    }));
}

@Test('Test the expected order of an action called during undo.')
void testActionDuringUndo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action(map, squareAsync, squareRootAsync);
  var action3 = new Action(map, increment, restore);
  
  var verifyUndo = expectAsync((success) {
    expect(success, isTrue);
    expect(map['val'], equals(43));
  });
  
  schedule(action1)
    .then((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    })
    .then((_) => schedule(action2))
    .then((result) {
      expect(result, equals(1849));
      expect(map['val'], equals(1849));
    })
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) {
      expect(schedule.canUndo, isTrue);   
      // The undo() needs to take more than 1 frame of the event loop
      // in order for this test case to be valid; we want to test that the
      // action is performed after the completion of the undo.
      schedule.undo().then(verifyUndo);
      return schedule(action3);
    })
    .then(expectAsync((result) {
      expect(result, equals(44));
      expect(map['val'], equals(44));
    }));
}

@Test('Test that an error thrown by a pending action does not affect undo.')
void testActionThrowsDuringUndo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action(map, squareAsync, squareRootAsync);
  var action3 = new Action(map, (a) => throw 'crowbar', restore);
  var _stackTrace;
  
  schedule(action1)
  .then((result) {
    expect(result, equals(43));
    expect(map['val'], equals(43));
  })
  .then((_) => schedule(action2))
  .then((result) {
    expect(result, equals(1849));
    expect(map['val'], equals(1849));
  })
  .then((_) => schedule.wait(Schedule.STATE_IDLE))
  .then((_) {
    expect(schedule.canUndo, isTrue);   
    // The undo() needs to take more than 1 frame of the event loop
    // in order for this test case to be valid; we want to test that the
    // action is performed after the completion of the undo, so that the
    // error is thrown in the flush state.
    schedule.undo().then((success) => 
        // The undo() should have success since the error should occur later.
        expect(success, isTrue));
    return schedule(action3);
  })
  .catchError(expectAsync((e, stackTrace) {   
    expect(e, equals('crowbar'));
    expect(schedule.stackTrace, isNotNull);
    _stackTrace = stackTrace;
  }))
  .then((_) => schedule.wait(Schedule.STATE_ERROR))
  .then(expectAsync((_) {
    expect(schedule.hasError, isTrue);
    expect(schedule.error, equals('crowbar'));
    expect(schedule.stackTrace, equals(_stackTrace));
  }));
}

@Test('Test the expected order of an action called during redo.')
void testActionDuringRedo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action(map, squareAsync, squareRootAsync);
  var action3 = new Action(map, increment, restore);
  
  schedule(action1)
    .then((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    })
    .then((_) => schedule(action2))
    .then((result) {
      expect(result, equals(1849));
      expect(map['val'], equals(1849));
    })
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) => schedule.undo())
    .then((success) {
      expect(success, isTrue);
      expect(map['val'], equals(43));
    })
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) {
      expect(schedule.canRedo, isTrue);   
      // The redo() needs to take more than 1 frame of the event loop
      // in order for this test case to be valid; we want to test that the
      // action is performed after the completion of the redo.
      schedule.redo().then((success) {
        expect(success, isTrue);
        expect(map['val'], equals(1849));
      });
      return schedule(action3);
    })
    .then(expectAsync((result) {
      expect(result, equals(1850));
      expect(map['val'], equals(1850));
    }));
}

@Test('Test that an error thrown by a pending action does not affect redo.')
void testActionThrowsDuringRedo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action(map, squareAsync, squareRootAsync);
  var action3 = new Action(map, (a) => throw 'crowbar', restore);
  var _stackTrace;
  
  schedule(action1);
  schedule(action2)
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) => schedule.undo())
    .then((success) {
      expect(success, isTrue);
      expect(map['val'], equals(43));
    })
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) {
      expect(schedule.canRedo, isTrue);   
      // The redo() needs to take more than 1 frame of the event loop
      // in order for this test case to be valid; we want to test that the
      // action is performed after the completion of the redo, so that the
      // error is thrown in the flush state.
      schedule.redo().then((success) => 
          // The redo() should have success since the error should occur later.
          expect(success, isTrue));      
      return schedule(action3);
    })
    .catchError(expectAsync((e, stackTrace) {   
      expect(e, equals('crowbar'));
      expect(stackTrace, isNotNull);
      _stackTrace = stackTrace;
    }))
    .then((_) => schedule.wait(Schedule.STATE_ERROR))
    .then(expectAsync((_) {
      expect(schedule.hasError, isTrue);
      expect(schedule.error, equals('crowbar'));
      expect(schedule.stackTrace, equals(_stackTrace));
    }));
}

@Test('Test the expected order of an action called during to.')
void testActionDuringTo() {
  var map = { 'val' : 42 };  
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action(map, squareAsync, squareRootAsync);
  var action3 = new Action(map, incrementAsync, restoreAsync);
  var action4 = new Action(map, square, squareRoot);
  
  action1();
  action2();
  action3()
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) {
      schedule.to(action1).then((success) {
        expect(success, isTrue);
        expect(map['val'], equals(43));
      });
      return action4();
    })
    .then(expectAsync((result) {
      expect(result, equals(1849));
      expect(map['val'], equals(1849));
    }));
}

@Test('Test that an error thrown by a pending action does not affect to.')
void testActionThrowsDuringTo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action(map, squareAsync, squareRootAsync);
  var action3 = new Action(map, incrementAsync, restoreAsync);
  var action4 = new Action(map, (a) => throw 'crowbar', squareRoot);
  var _stackTrace;
  
  schedule(action1);
  schedule(action2);
  schedule(action3)
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) {
      schedule.to(action1).then((success) => 
          // The to() should have success since the error should occur later.
          expect(success, isTrue)); 
      return schedule(action4);
    })
    .catchError(expectAsync((e, stackTrace) {  
      expect(e, equals('crowbar'));
      expect(stackTrace, isNotNull);
      _stackTrace = stackTrace;
    }))
    .then((_) => schedule.wait(Schedule.STATE_ERROR))
    .then(expectAsync((_) {
      expect(schedule.hasError, isTrue);
      expect(schedule.error, equals('crowbar'));
      expect(schedule.stackTrace, equals(_stackTrace));
    }));
}

@Test('Test that an action called in the flush state is done before idle.')
void testActionDuringFlush() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, squareAsync, squareRootAsync);
  var action2 = new Action(map, increment, decrement);  
  var action3 = new Action(map, incrementAsync, restoreAsync);
  var action4 = new Action(map, square, squareRoot);
  
  // Schedule an async action.
  schedule(action1);
  // Schedule two more actions that should queue up as pending.
  schedule(action2);
  schedule(action3);
  
  bool wentToIdle = false;
  bool wentToFlush = false;
  
  var finish = expectAsync((result) {
    // Make sure the state machine does not glitch to IDLE before FLUSH
    expect(wentToIdle, isFalse);    
    expect(result, equals(3118756));
    expect(map['val'], equals(3118756));
  });
  
  // Observe the state transition to STATE_FLUSH.
  schedule.states.listen((state) {
    if (state == Schedule.STATE_IDLE && !wentToFlush) wentToIdle = true;
    if (state == Schedule.STATE_FLUSH) {
      // We expect to only transition to STATE_FLUSH one time.
      expect(wentToFlush, isFalse);
      wentToFlush = true;
      // Schedule another action which we expect to finish before STATE_IDLE.
      schedule(action4).then(finish);
    }
  });
}

// -----------------------------------------------------------------------------
// Transaction
// -----------------------------------------------------------------------------

@Test('Test that a transaction computes as expected.')
void testTransaction() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  
  var transaction = new Transaction()
  ..add(new Action(map, increment, decrement))
  ..add(new Action(map, square, squareRoot))
  ..add(new Action(map, increment, restore));
  
  schedule(transaction)
    .then(expectAsync((_) => expect(map['val'], equals(1850))));
}

@Test('Test that adding a null action to a transaction throws an error.')
@ExpectError(isArgumentError)
void testTransactionAddNullActionThrows() {
  new Transaction()..add(null);  
}

@Test('Test that adding a !undoable action to a transaction throws an error.')
@ExpectError(isArgumentError)
void testTransactionAddNonUndoableActionThrows() {
  new Transaction()..add(new Action({ 'val' : 42 }, increment, null));
}

@Test('Test that a transaction rollback succeeds when an error is thrown.')
void testTransactionRollback() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  
  var transaction = new Transaction()
  ..add(new Action(map, increment, decrement))
  ..add(new Action(map, square, squareRoot))
  ..add(new Action(map, (a) => throw 'bomb', restore));
  
  schedule(transaction)
    .catchError(expectAsync((e, stackTrace) {
      expect(e, const isInstanceOf<TransactionError>());
      expect(stackTrace, isNotNull);
      expect(e.cause, equals("bomb"));  
      expect(e.causeStackTrace, stackTrace);
      expect(e.rollbackError, isNull);
      expect(e.rollbackStackTrace, isNull);
      expect(map['val'], equals(42));
   }));
}

@Test('Test the handling of an error thrown during transaction rollback.')
void testTransactionRollbackError() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  
  var transaction = new Transaction()
  ..add(new Action(map, increment, (a, r) => throw 'nuke'))
  ..add(new Action(map, square, squareRoot))
  ..add(new Action(map, (a) => throw 'bomb', restore));
  
  schedule(transaction)
    .catchError(expectAsync((e, stackTrace) {
      expect(e, const isInstanceOf<TransactionError>());
      expect(stackTrace, isNotNull);
      expect(e.cause, equals("bomb"));
      expect(e.causeStackTrace, stackTrace);
      expect(e.rollbackError, equals("nuke"));
      expect(e.rollbackStackTrace, isNotNull);
      expect(e.rollbackStackTrace, isNot(stackTrace));
      expect(map['val'], equals(43));
   }));  
}

@Test('Test the successful completion of a transaction undo operation.')
void testTransactionUndo() {    
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  
  var transaction = new Transaction()
  ..add(new Action(map, increment, decrement))
  ..add(new Action(map, square, squareRoot))
  ..add(new Action(map, increment, restore));
  
  schedule(transaction)
    .then((_) => expect(map['val'], equals(1850)))
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    .then((_) => schedule.undo())
    .then(expectAsync((success) {
      expect(success, isTrue);
      expect(map['val'], equals(42));
    }));
}

@Test('Test that a transact builds and computes a transaction as expected.')
void testTransact() {
  var map = { 'val' : 42 };
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action(map, square, squareRoot);
  var action3 = new Action(map, increment, restore);      
  transact(() {
    // Verify that continuations chained on each action get the proper result.
    action1().then(expectAsync((result) => expect(result, equals(43))));
    action2().then(expectAsync((result) => expect(result, equals(1849))));
    action3().then(expectAsync((result) => expect(result, equals(1850))));
  }).then(expectAsync((_) => expect(map['val'], equals(1850))));    
}

@Test('Test that an error thrown in the body of transact is handled.')
void testTransactThrows() {
  var map = { 'val' : 42 };
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action(map, square, squareRoot);
  transact(() {
    action1().then((_) => throw 'should not happen!');
    action2().then((_) => throw 'should not happen!');
    throw 'trouble';
  })
  .catchError(expectAsync((e, stackTrace) {
    expect(e, equals('trouble'));
    expect(stackTrace, isNotNull);
  }));  
  // Verify that we can successfully do a transaction now.
  transact(() {
    action1().then(expectAsync((result) => expect(result, equals(43))));
    action2().then(expectAsync((result) => expect(result, equals(1849))));
  }).then(expectAsync((_) => expect(map['val'], equals(1849))));
}

// -----------------------------------------------------------------------------
// States
// -----------------------------------------------------------------------------

@Test('Test that no events are added to the states stream if no listeners.')
void testNoStatesListener() {
  var schedule = new Schedule();
  // Do an action to cause state transitions to happen.
  var action = new Action(14, (x) => x + 1, (x, y) => x - 1);
  schedule(action).then(expectAsync((result) {
    expect(result, equals(15));    
    final noop = expectAsync(() {});
    
    // Defer to let the schedule return to idle.
    scheduleMicrotask(() {
      expect(schedule.isBusy, isFalse);
      
      // Now attach a listener.
      schedule.states.listen((state) {
        fail('No states should be buffered.');
      });
      
      // Delay test completion to make sure no events are flushed to listener.
      scheduleMicrotask(noop);
    });
  }));
}

@Test('Test that events are buffered by a paused states stream subscriber.')
void testPauseStatesListener() {
  var schedule = new Schedule();
  
  // Attach a listener, we expect to see both the CALL and IDLE states.
  var subscribe = expectTwoEvents(schedule.states);
  
  // Pause the subscription.
  subscribe.pause();
  
  // Do an action to cause state transitions to happen.
  var action = new Action(14, (x) => x + 1, (x, y) => x - 1);
  schedule(action)
    .then(expectAsync((result) => expect(result, equals(15))))
    .then((_) => schedule.wait(Schedule.STATE_IDLE))
    // Resume the subscription.
    .then((_) => subscribe.resume());
}

@Test('Test that the states stream is a broadcast stream.')
void testStatesIsBroadcast() {
  var schedule = new Schedule();
  schedule.states.listen((state) { /* noop */ });
  schedule.states.listen((state) { /* noop */ });
}

@Test('Test that calling wait w/ an invalid state results in an error.')
@ExpectError(isArgumentError)
testWaitBadState() => schedule.wait('bad');
