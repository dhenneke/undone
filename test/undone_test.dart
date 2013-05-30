
library undone.test;

import 'dart:async';
import 'dart:math' as math;
import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart';
import 'package:undone/undone.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) => print('${record.message}'));
  
  group('[basic]', () {
    setUp(() => waitIdle(schedule).then((_) => schedule.clear()));
    test('Test the initial state of a freshly constructed schedule.', 
        testScheduleInitialState);
    test('Test that action constructors succeed when given valid arguments.', 
        testActionConstructor);
    test('Test that action constructors throw ArgumentError on null functions.', 
        testActionConstructorNullThrows);
    test('Test that an action computes as expected.', testAction);
    test('Test that an async action computes as expected.', testActionAsync);
    test('Test that an error thrown by an action is handled as expected.', 
        testActionThrows);
    test('Test that an attempt to schedule the same action twice throws error.',
        testScheduleSameActionTwiceThrows);
    test('Test that an action call throws StateError if the Schedule hasError.', 
        testScheduleHasErrorActionThrows);
    test('Test the successful completion of an undo operation.', testUndo);
    test('Test that an error thrown by an action undo is handled as expected.', 
        testUndoThrows);
    test('Test the successful completion of an redo operation.', testRedo);
    test('Test that an error thrown by an action redo is handled as expected.', 
        testRedoThrows);
    test('Test that an undo operation returns false if canUndo is false.', 
        testUndoEmptyScheduleReturnsFalse);
    test('Test that a redo operation returns false if canRedo is false.', 
        testRedoEmptyScheduleReturnsFalse);
    test('Test the successful completion of a to operation.', testTo);
    test('Test the successful clear of a schedule.', testClear);
  });
  group('[concurrent]', () {
    setUp(() => waitIdle(schedule).then((_) => schedule.clear()));
    test('Test the expected order of two concurrent actions.', 
        testActionDuringAction);
    test('Test that an error thrown by a pending action does not affect other.', 
        testActionThrowsDuringAction);
    test('Test the expected order of multiple concurrent actions.', 
        testMultipleActionsDuringAction);
    test('Test that an attempt to defer the same action twice throws error.',
        testDeferSameActionTwiceThrows);
    test('Test the expected order of an action called during undo.', 
        testActionDuringUndo);   
    test('Test that an error thrown by a pending action does not affect undo.',
        testActionThrowsDuringUndo);
    test('Test the expected order of an action called during redo.', 
        testActionDuringRedo);
    test('Test that an error thrown by a pending action does not affect redo.', 
        testActionThrowsDuringRedo);
    test('Test the expected order of an action called during to.', 
        testActionDuringTo);
    test('Test that an error thrown by a pending action does not affect to.', 
        testActionThrowsDuringTo);
    test('Test that an action called in the flush state is done before idle.', 
        testActionDuringFlush);    
  });  
  group('[transaction]', () {
    setUp(() => waitIdle(schedule).then((_) => schedule.clear()));
    test('Test that a transaction computes as expected.', testTransaction);
    test('Test that a transaction rollback succeeds when an error is thrown.', 
        testTransactionRollback);
    test('Test the handling of an error thrown during transaction rollback.', 
        testTransactionRollbackError);
    test('Test the successful completion of a transaction undo operation.', 
        testTransactionUndo);
    test('Test that a transact builds and computes a transaction as expected.', 
        testTransact);
    test('Test that an error thrown in the body of transact is handled.', 
        testTransactThrows);
  });
  group('[states]', () {
    setUp(() => waitIdle(schedule).then((_) => schedule.clear()));
    test('Test that no events are added to the states stream if no listeners.', 
        testNoStatesListener);
    test('Test that no events are added to the states stream when paused.', 
        testPauseStatesListener);
    test('Test that the states stream is not a broadcast stream.', 
         testStatesNotBroadcast);
  });
}

// -----------------------------------------------------------------------------
// Setup
// -----------------------------------------------------------------------------

// Top-level functions used across test cases; stateless.
Do increment = (a) { a['oldValue'] = a['val']; return ++a['val']; };
Undo decrement = (a, _) => --a['val'];
Undo restore = (a, _) => a['val'] = a['oldValue'];
Do square = (a) => a['val'] = a['val'] * a['val'];  
Undo squareRoot = (a, _) => a['val'] = math.sqrt(a['val']);

// TODO(rms): we could make these delays random (keep them small though).
DoAsync incrementAsync = (a) => 
    new Future.delayed(const Duration(milliseconds: 4), () => increment(a));
UndoAsync decrementAsync = (a, _) => 
    new Future.delayed(const Duration(milliseconds: 5), () => decrement(a, _));
UndoAsync restoreAsync = (a, _) => 
    new Future.delayed(const Duration(milliseconds: 2), () => restore(a, _));
DoAsync squareAsync = (a) => 
    new Future.delayed(const Duration(milliseconds: 3), () => square(a));
UndoAsync squareRootAsync = (a, _) => 
    new Future.delayed(const Duration(milliseconds: 5), () => squareRoot(a, _));

Future waitError(Schedule s) {
  if (s.hasError) return new Future.value(Schedule.STATE_ERROR);
  return s.states.firstWhere((state) => state == Schedule.STATE_ERROR);
}

Future waitIdle(Schedule s) {
  if (!s.busy) return new Future.value(Schedule.STATE_IDLE);
  return s.states.firstWhere((state) => state == Schedule.STATE_IDLE);
}

// -----------------------------------------------------------------------------
// Basic
// -----------------------------------------------------------------------------

void testScheduleInitialState() {
  var schedule = new Schedule();
  expect(schedule.busy, isFalse);
  expect(schedule.canClear, isTrue);  
  expect(schedule.canRedo, isFalse);  
  expect(schedule.canUndo, isFalse);  
  expect(schedule.hasError, isFalse);  
  expect(schedule.error, isNull);
}

void testActionConstructor() {
  var action = new Action(7, (x) => x + 1, (x, y) => x = y);
  var actionAsync = new Action.async(11, 
      (x) => new Future.delayed(const Duration(milliseconds: 5), () => x - 1), 
      (x, y) =>new Future.delayed(const Duration(milliseconds: 3), () => x = y));
}

void testActionConstructorNullThrows() {
  expect(() => new Action(7, null, (x, y) => x = y), 
      throwsA(const isInstanceOf<ArgumentError>()));
  expect(() => new Action(7, (x) => x + 1, null), 
      throwsA(const isInstanceOf<ArgumentError>()));
  expect(() => new Action.async(11, null, 
      (x, y) =>new Future(() => x = y)), 
      throwsA(const isInstanceOf<ArgumentError>()));
  expect(() => new Action.async(11,
      (x) => new Future(() => x - 1), null), 
      throwsA(const isInstanceOf<ArgumentError>())); 
}

void testAction() {
  var action = new Action(14, (x) => x + 1, (x, y) => x - 1);
  action().then(expectAsync1((result) => expect(result, equals(15))));
}

void testActionAsync() {
  var action = new Action.async(11, 
      (x) => new Future.delayed(const Duration(milliseconds: 5), () => x - 1), 
      (x, y) =>new Future.delayed(const Duration(milliseconds: 3), () => x = y));
  action().then(expectAsync1((result) => expect(result, equals(10))));
}

void testActionThrows() {
  var schedule = new Schedule();
  var action = new Action(14, (x) => throw 'snarf', (x, y) => true);  
  schedule(action)
    .catchError(expectAsync1((e) { 
      expect(e, equals('snarf'));
      expect(schedule.hasError, isTrue);
      expect(schedule.error, equals(e));
   }));
}

void testScheduleSameActionTwiceThrows() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  var action = new Action(map, increment, decrement);
  
  schedule(action)
    .then(expectAsync1((result) => expect(result, equals(43))))
    .then((_) => schedule(action))
    .catchError(expectAsync1((e) {
      expect(e, const isInstanceOf<StateError>());
      expect(schedule.hasError, isTrue);
      expect(schedule.error, equals(e));
    }));
}

void testScheduleHasErrorActionThrows() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  var action1 = new Action(map, (x) => throw 'snarf', decrement);
  var action2 = new Action(map, increment, decrement);
  
  // The first action should throw and put the schedule in an error state.
  schedule(action1)
    .catchError((e) {  
      expect(e, equals('snarf'));
      expect(schedule.hasError, isTrue);
      expect(schedule.error, equals(e));
    })
    // The second action should cause a StateError to be thrown.
    .then((_) => schedule(action2))
    .catchError(expectAsync1((e) {   
      expect(e, const isInstanceOf<StateError>());
    }));
}

void testUndo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  var action = new Action(map, increment, decrement);
  schedule(action)
    .then((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    })
    .then((_) => waitIdle(schedule))
    .then((_) => schedule.undo())
    .then(expectAsync1((success) {
      expect(success, isTrue);
      expect(map['val'], equals(42));
    }));
}

void testUndoThrows() {
  var schedule = new Schedule(); 
  var map = { 'val' : 42 };
  var action = new Action(map, increment, (a, r) => throw 'uh-oh');
  schedule(action)
    .then((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    })
    .then((_) => waitIdle(schedule))
    .then((_) => schedule.undo())
    .catchError(expectAsync1((e) { 
      expect(e, equals('uh-oh'));
      expect(schedule.hasError, isTrue);
      expect(schedule.error, e);
   }));
}

void testRedo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  var action = new Action(map, increment, decrement);
  schedule(action)
    .then((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    })
    .then((_) => waitIdle(schedule))
    .then((_) => schedule.undo())
    .then((success) {
      expect(success, isTrue);
      expect(map['val'], equals(42));
    })
    .then((_) => waitIdle(schedule))
    .then((_) => schedule.redo())
    .then(expectAsync1((success) {
      expect(success, isTrue);
      expect(map['val'], equals(43));
    }));
}

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
    .then((_) => waitIdle(schedule))
    .then((_) => schedule.undo())
    .then((success) {
      expect(success, isTrue);
      expect(map['val'], equals(42));
    })
    .then((_) => waitIdle(schedule))
    .then((_) => schedule.redo())
    .catchError(expectAsync1((e) { 
      expect(e, equals('overdone'));
      expect(schedule.hasError, isTrue);
      expect(schedule.error, e);
   }));
}

void testUndoEmptyScheduleReturnsFalse() {
  new Schedule()
    .undo().then(expectAsync1((success) => expect(success, isFalse)));
}

void testRedoEmptyScheduleReturnsFalse() {
  new Schedule()
    .redo().then(expectAsync1((success) => expect(success, isFalse)));
}

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
    })
    .then((_) => waitIdle(schedule))
    .then((_) => schedule.to(action1))
    .then((success) {
      expect(success, isTrue);
      expect(map['val'], equals(43));
    })    
    .then((_) => waitIdle(schedule))
    .then((_) => schedule.to(action3))
    .then(expectAsync1((success) {
      expect(success, isTrue);
      expect(map['val'], equals(1850));
    }));
}

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
    .then((_) => waitIdle(schedule))
    .then(expectAsync1((_) {
      expect(schedule.canClear, isTrue);
      expect(schedule.clear(), isTrue);
      expect(schedule.canClear, isTrue);
      expect(schedule.canUndo, isFalse);
      expect(schedule.canRedo, isFalse);
      expect(schedule.hasError, isFalse);
      expect(schedule.error, isNull);
    }));
}

// -----------------------------------------------------------------------------
// Concurrent
// -----------------------------------------------------------------------------

void testActionDuringAction() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action.async(map, incrementAsync, decrementAsync);
  var action2 = new Action(map, square, squareRoot);
  
  // Schedule an async action that takes more than 1 tick.
  schedule(action1)
    .then(expectAsync1((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    }));
  
  // Schedule a synchronous action that we expect to be done after the first.
  schedule(action2)
    .then(expectAsync1((result) {
      expect(result, equals(1849));
      expect(map['val'], equals(1849));
    }));
}

void testActionThrowsDuringAction() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action.async(map, incrementAsync, decrementAsync);
  var action2 = new Action(map, (a) => throw 'crowbar', squareRoot);
  
  // Schedule an async action that takes more than 1 tick.
  schedule(action1)
    .then(expectAsync1((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    }));
  
  // Schedule a synchronous action that we expect to be called after the first
  // completes, so we expect the thrown error to have no affect on the first.
  schedule(action2)
    .catchError(expectAsync1((e) {    
      expect(e, equals('crowbar'));    
    }))
    .then((_) => waitError(schedule))
    .then(expectAsync1((_) {
      expect(schedule.hasError, isTrue);
      expect(schedule.error, equals('crowbar'));
    }));
}

void testMultipleActionsDuringAction() {  
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action.async(map, incrementAsync, decrementAsync);
  var action2 = new Action(map, square, squareRoot);
  var action3 = new Action.async(map, squareAsync, squareRootAsync);
  var action4 = new Action(map, increment, restore);
  
  schedule(action1)
    .then(expectAsync1((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    }));
  
  schedule(action2)
    .then(expectAsync1((result) {
      expect(result, equals(1849));
      expect(map['val'], equals(1849));
    }));
  
  schedule(action3)
    .then(expectAsync1((result) {
      expect(result, equals(3418801));
      expect(map['val'], equals(3418801));
    })); 
  
  schedule(action4)
    .then(expectAsync1((result) {
      expect(result, equals(3418802));
      expect(map['val'], equals(3418802));
    }));  
}

void testDeferSameActionTwiceThrows() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action.async(map, incrementAsync, decrementAsync);
  var action2 = new Action(map, square, squareRoot);
  
  // Schedule an async action that takes more than 1 tick.
  schedule(action1)
    .then(expectAsync1((result) {
      expect(result, equals(43));
      expect(map['val'], equals(43));
    }));
  
  // Schedule another action 2 times, expecting error on the second schedule.
  
  schedule(action2)
    .then(expectAsync1((result) {
      expect(result, equals(1849));
      expect(map['val'], equals(1849));
    }));
  
  schedule(action2)
    .catchError(expectAsync1((e) {
      expect(e, const isInstanceOf<StateError>());
      expect(schedule.hasError, isTrue);
      expect(schedule.error, equals(e));
    }));
}

void testActionDuringUndo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action.async(map, squareAsync, squareRootAsync);
  var action3 = new Action(map, increment, restore);
  
  var verifyUndo = expectAsync1((success) {
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
    .then((_) => waitIdle(schedule))
    .then((_) {
      expect(schedule.canUndo, isTrue);   
      // The undo() needs to take more than 1 frame of the event loop
      // in order for this test case to be valid; we want to test that the
      // action is performed after the completion of the undo.
      schedule.undo().then(verifyUndo);
      return schedule(action3);
    })
    .then(expectAsync1((result) {
      expect(result, equals(44));
      expect(map['val'], equals(44));
    }));
}

void testActionThrowsDuringUndo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action.async(map, squareAsync, squareRootAsync);
  var action3 = new Action(map, (a) => throw 'crowbar', restore);
  
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
  .then((_) => waitIdle(schedule))
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
  .catchError(expectAsync1((e) {   
    expect(e, equals('crowbar'));    
  }))
  .then((_) => waitError(schedule))
  .then(expectAsync1((_) {
    expect(schedule.hasError, isTrue);
    expect(schedule.error, equals('crowbar'));
  }));
}

void testActionDuringRedo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action.async(map, squareAsync, squareRootAsync);
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
    .then((_) => waitIdle(schedule))
    .then((_) => schedule.undo())
    .then((success) {
      expect(success, isTrue);
      expect(map['val'], equals(43));
    })
    .then((_) => waitIdle(schedule))
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
    .then(expectAsync1((result) {
      expect(result, equals(1850));
      expect(map['val'], equals(1850));
    }));
}

void testActionThrowsDuringRedo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action.async(map, squareAsync, squareRootAsync);
  var action3 = new Action(map, (a) => throw 'crowbar', restore);
  
  schedule(action1);
  schedule(action2)
    .then((_) => waitIdle(schedule))
    .then((_) => schedule.undo())
    .then((success) {
      expect(success, isTrue);
      expect(map['val'], equals(43));
    })
    .then((_) => waitIdle(schedule))
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
    .catchError(expectAsync1((e) {   
      expect(e, equals('crowbar'));    
    }))
    .then((_) => waitError(schedule))
    .then(expectAsync1((_) {
      expect(schedule.hasError, isTrue);
      expect(schedule.error, equals('crowbar'));
    }));
}

void testActionDuringTo() {
  var map = { 'val' : 42 };  
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action.async(map, squareAsync, squareRootAsync);
  var action3 = new Action(map, incrementAsync, restoreAsync);
  var action4 = new Action(map, square, squareRoot);
  
  action1();
  action2();
  action3()
    .then((_) => waitIdle(schedule))
    .then((_) {
      schedule.to(action1).then((success) {
        expect(success, isTrue);
        expect(map['val'], equals(43));
      });
      return action4();
    })
    .then(expectAsync1((result) {
      expect(result, equals(1849));
      expect(map['val'], equals(1849));
    }));
}

void testActionThrowsDuringTo() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action.async(map, squareAsync, squareRootAsync);
  var action3 = new Action(map, incrementAsync, restoreAsync);
  var action4 = new Action(map, (a) => throw 'crowbar', squareRoot);
  
  schedule(action1);
  schedule(action2);
  schedule(action3)
    .then((_) => waitIdle(schedule))
    .then((_) {
      schedule.to(action1).then((success) => 
          // The to() should have success since the error should occur later.
          expect(success, isTrue)); 
      return schedule(action4);
    })
    .catchError(expectAsync1((e) {  
      expect(e, equals('crowbar'));    
    }))
    .then((_) => waitError(schedule))
    .then(expectAsync1((_) {
      expect(schedule.hasError, isTrue);
      expect(schedule.error, equals('crowbar'));
    }));
}

void testActionDuringFlush() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };  
  var action1 = new Action.async(map, squareAsync, squareRootAsync);
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
  
  var finish = expectAsync1((result) {
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

void testTransaction() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  
  var transaction = 
      new Transaction()
          ..add(new Action(map, increment, decrement))
          ..add(new Action(map, square, squareRoot))
          ..add(new Action(map, increment, restore));
  
  schedule(transaction)
    .then(expectAsync1((_) => expect(map['val'], equals(1850))));
}

void testTransactionRollback() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  
  var transaction = 
      new Transaction()
          ..add(new Action(map, increment, decrement))
          ..add(new Action(map, square, squareRoot))
          ..add(new Action(map, (a) => throw 'bomb', restore));
  
  schedule(transaction)
    .catchError(expectAsync1((e) {
      expect(e, const isInstanceOf<TransactionError>());
      expect(e.cause, equals("bomb"));
      expect(e.rollbackError, isNull);
      expect(map['val'], equals(42));
   }));
}

void testTransactionRollbackError() {
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  
  var transaction = 
      new Transaction()
          ..add(new Action(map, increment, (a, r) => throw 'nuke'))
          ..add(new Action(map, square, squareRoot))
          ..add(new Action(map, (a) => throw 'bomb', restore));
  
  schedule(transaction)
    .catchError(expectAsync1((e) {
      expect(e, const isInstanceOf<TransactionError>());
      expect(e.cause, equals("bomb"));
      expect(e.rollbackError, equals("nuke"));
      expect(map['val'], equals(43));
   }));  
}

void testTransactionUndo() {    
  var schedule = new Schedule();
  var map = { 'val' : 42 };
  
  var transaction = 
      new Transaction()
          ..add(new Action(map, increment, decrement))
          ..add(new Action(map, square, squareRoot))
          ..add(new Action(map, increment, restore));
  
  schedule(transaction)
    .then((_) => expect(map['val'], equals(1850)))
    .then((_) => waitIdle(schedule))
    .then((_) => schedule.undo())
    .then(expectAsync1((success) {
      expect(success, isTrue);
      expect(map['val'], equals(42));
    }));
}

void testTransact() {
  var map = { 'val' : 42 };
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action(map, square, squareRoot);
  var action3 = new Action(map, increment, restore);      
  transact(() {
    // Verify that continuations chained on each action get the proper result.
    action1().then(expectAsync1((result) => expect(result, equals(43))));
    action2().then(expectAsync1((result) => expect(result, equals(1849))));
    action3().then(expectAsync1((result) => expect(result, equals(1850))));
  }).then(expectAsync1((_) => expect(map['val'], equals(1850))));    
}

void testTransactThrows() {
  var map = { 'val' : 42 };
  var action1 = new Action(map, increment, decrement);
  var action2 = new Action(map, square, squareRoot);
  transact(() {
    action1().then((_) => throw 'should not happen!');
    action2().then((_) => throw 'should not happen!');
    throw 'trouble';
  })
  .catchError(expectAsync1((e) {
    expect(e, equals('trouble'));
  }));  
  // Verify that we can successfully do a transaction now.
  transact(() {
    action1().then(expectAsync1((result) => expect(result, equals(43))));
    action2().then(expectAsync1((result) => expect(result, equals(1849))));
  }).then(expectAsync1((_) => expect(map['val'], equals(1849))));
}

// -----------------------------------------------------------------------------
// States
// -----------------------------------------------------------------------------

void testNoStatesListener() {
  var schedule = new Schedule();
  // Do an action to cause state transitions to happen.
  var action = new Action(14, (x) => x + 1, (x, y) => x - 1);
  schedule(action).then(expectAsync1((result) {
    expect(result, equals(15));    
    final noop = expectAsync0(() { });
    
    // Defer to let the schedule return to idle.
    runAsync(() {
      expect(schedule.busy, isFalse);
      
      // Now attach a listener.
      schedule.states.listen((state) {
        fail('No states should be buffered.');
      });
      
      // Delay test completion to make sure no events are flushed to listener.
      runAsync(noop);
    });
  }));  
}

void testPauseStatesListener() {
  var schedule = new Schedule();
  
  // Attach a listener.
  var subscribe = schedule.states.listen((state) {
    fail('No states should be buffered during pause.');
  });
  
  // Pause the subscription.
  subscribe.pause();
  
  // Do an action to cause state transitions to happen.
  var action = new Action(14, (x) => x + 1, (x, y) => x - 1);
  schedule(action).then(expectAsync1((result) {
    expect(result, equals(15));    
    final noop = expectAsync0(() { });
    
    // Defer to let the schedule return to idle.
    runAsync(() {
      expect(schedule.busy, isFalse);
      
      // Resume the subscription.
      subscribe.resume();
      
      // Delay test completion to make sure no events are flushed to listener.
      runAsync(noop);
    });
  }));  
}

void testStatesNotBroadcast() {
  var schedule = new Schedule();
  schedule.states.listen((state) { /* noop */ });  
  expect(() { 
    schedule.states.listen((state) { /* noop */ }); 
  }, throwsA(isStateError));
}
