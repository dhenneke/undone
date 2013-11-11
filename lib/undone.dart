
/// A library for undo and redo.
library undone;

import 'dart:async';
import 'package:logging/logging.dart';

/// A function to do an operation on an [arg] and return a result.
typedef R Do<A, R>(A arg);

/// A function to do an async operation on an [arg] and complete a result.
typedef Future<R> DoAsync<A, R>(A arg);

/// A function to undo an operation on an [arg] given the prior [result].
typedef void Undo<A, R>(A arg, R result);

/// A function to undo an async operation on an [arg] given the prior [result].
typedef Future UndoAsync<A, R>(A arg, R result);

Logger _logger = new Logger('undone');

Schedule _schedule;
/// The isolate's top-level [Schedule].
Schedule get schedule {
  if (_schedule == null) _schedule = new Schedule();
  return _schedule;
}

Transaction _transaction;
/// Build and compute a [Transaction] using the top-level [schedule].
/// 
/// Returns a Future for the transaction's completion.
Future transact(void build()) {
  assert(_transaction == null);  
  var txn = new Transaction();
  _transaction = txn;
  try {
    build();
  } catch(e, stackTrace) {
    // Clear the deferred future for each action that was added in the build.
    _transaction._arg.forEach((action) => action._deferred = null);
    return new Future.error(e, stackTrace);
  } finally {
    _transaction = null;
  }
  return txn();
}

/// Undo the next action to be undone in the top-level [schedule], if any.
/// 
/// Completes `true` if an action was undone or else completes `false`.
Future<bool> undo() => schedule.undo();

/// Redo the next action to be redone in the top-level [schedule], if any.
/// 
/// Completes `true` if an action was redone or else completes `false`.
Future<bool> redo() => schedule.redo();

/// An action that can be done and undone.
///
/// Actions are comprised of a pair of functions: one to [Do] the action and
/// another to [Undo] the action.  The action object is itself a function that 
/// can be [call]ed to schedule it to be done on the top-level [schedule] or
/// to add it to a [Transaction] if called within the scope of [transact].
/// Actions may also be created with a pair of [DoAsync] and [UndoAsync]
/// functions using the [new Action.async] constructor.  All actions are done
/// and undone asynchronously, regardless of the functions themselves.  Actions
/// may be optionally typed by their argument and result objects, [A] and [R].
/// The action type may be extended to define custom actions although this may
/// often not be necessary; creating an action with the functions to do and
/// undo the desired operation is often the simplest and best approach.
class Action<A, R> {
      
  final A _arg;
  R _result; // The result of the most recent call().
  final DoAsync _do;
  final UndoAsync _undo;
  Completer _deferred;
  
  /// Whether or not this action can be undone.
  final bool canUndo;
  
  /// The maximum allowed duration for this action's [Do] or [Undo] function.
  /// 
  /// A `null` value represents no timeout, and is the default for actions
  /// created with the [new Action] constructor.  For actions created with
  /// the [new Action.async] constructor the default value is 30 seconds unless
  /// otherwise specified.
  /// 
  /// When a timeout occurs, this action will complete with an error.
  final Duration timeout;
  
  /// Creates a new action with the given [arg]uments, [Do] function, and 
  /// [Undo] function.  
  /// 
  /// The given synchronous functions are automatically wrapped in futures prior 
  /// to being called on a schedule.
  Action(
      A arg, 
      Do d, 
      [Undo u]) 
  : this._(
      arg, 
      d == null ? d : (a) => new Future.sync(() => d(a)), 
      u == null ? u : (a, r) => new Future.sync(() => u(a, r)));
  
  /// Creates a new action with the given [arg]uments, [DoAsync] function, 
  /// [UndoAsync] function, and timeout [Duration].
  Action.async(
      A arg, 
      DoAsync d, 
     [UndoAsync u, 
      Duration timeout = const Duration(seconds: 30)]) 
  : this._(arg, d, u, timeout);
  
  Action._(
      this._arg, 
      this._do, 
      UndoAsync undo, 
     [Duration timeout]) 
  : canUndo = (undo != null)
  , timeout = timeout
  , _undo = undo {
    if (_do == null) {
      throw new ArgumentError('Do function must be !null.');    
    }
  }
  
  /// Schedules this action to be called on the top-level [schedule].  
  /// 
  /// If this action is called within the scope of a top-level [transact] method
  /// it will instead be added to that transaction.  Completes with the result 
  /// of the action in both cases.
  Future<R> call() {    
    if (_transaction != null) {
      _transaction.add(this);
      return this._defer();
    }
    return schedule(this);
  }
  
  Future<R> _defer() {    
    // The action may only give out 1 deferred future at a time.
    assert(_deferred == null);
    _deferred = new Completer<R>();
    return _deferred.future;
  }
    
  Future<R> _execute() {
    if (_deferred == null) {
      return _guard(_do(_arg));
    } else {
      // If the action was deferred, we complete the future we handed out prior.
      return _guard(_do(_arg))
        .then((result) {
          _deferred.complete(result);
          return new Future.value(result);
        })
        .catchError(
            (e) => throw new StateError('Error wrongfully caught.'), 
            // TODO(rms): https://code.google.com/p/dart/issues/detail?id=14855
            test: (e) {
              // Complete the error to the deferred future, but allow the error
              // to propogate back to the schedule also so that it can 
              // transition to its error state.
              _deferred.completeError(e);
              return false;
            })
        .whenComplete(() => _deferred = null);
    }
  }
  
  Future _guard(Future f) {
    if (timeout == null) {
      return f; 
    }
    final completer = new Completer();
    final timer = new Timer(timeout, () {
      completer.completeError(new StateError(
          '$this timed out after ${timeout.inSeconds} seconds.'));
    });
    f
    .then((result) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    })
    .catchError((e, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(e, stackTrace);
      }
    })
    .whenComplete(() {
      timer.cancel();
    });
    return completer.future;
  }
  
  Future _unexecute() => _guard(_undo(_arg, _result));  
  
  String toString() => 'action($hashCode)';
}

/// An error encountered during a transaction.
class TransactionError extends Error {
  
  /// The caught object that caused the transaction to err.
  final cause;
  
  /// The stack trace associated with the [cause], if any.
  final causeStackTrace;
  
  var _rollbackError;
  var _rollbackStackTrace;
  
  /// An error encountered during transaction rollback; may be `null` if none.
  get rollbackError => _rollbackError;
  
  /// The stack trace associated with the [rollbackError], if any.
  get rollbackStackTrace => _rollbackStackTrace;
  
  /// Creates a new transaction error with the given cause.
  TransactionError(this.cause, [this.causeStackTrace]);
}

/// A sequence of actions that are done and undone together as if one action.
///
/// A transaction is itself an action that may be [call]ed on a schedule.
/// When a transaction is scheduled to be done or undone it will do or undo
/// all of its actions in sequence.  Any errors that occur when doing one of
/// its actions will cause the transaction to attempt to undo all of its actions
/// that were done prior to the error; this is known as rollback.  These errors
/// will be wrapped in a [TransactionError] and completed to the caller.
class Transaction extends Action {
  
  static Future _do_(List<Action> actions) {
    var completer = new Completer<List>();            
    var current;
    // Try to do all the actions in order.
    Future.forEach(actions, (action) {
      // Keep track of the current action in case an error happens.
      current = action;
      return action._execute();
    }).then((_) => completer.complete())
      .catchError((e, stackTrace) {
        final err = new TransactionError(e, stackTrace);
        final reverse = actions.reversed.skipWhile((a) => a == current);
        // Try to undo from the point of failure back to the start.
        Future.forEach(reverse, (action) => action._unexecute())
          // We complete with error even if rollback succeeds.
          .then((_) => completer.completeError(err))
          .catchError((e, stackTrace) { 
            // Double trouble, give both errors to the caller.
            err._rollbackError = e;
            err._rollbackStackTrace = stackTrace;
            completer.completeError(err);
          });
      });
    return completer.future;
  }
  
  static Future _undo_(List<Action> actions, _) => 
      Future.forEach(actions.reversed, (action) => action._unexecute());
  
  /// Creates a new empty transaction.
  Transaction() : super._(new List<Action>(), _do_, _undo_);
  
  /// Adds the given [action] to this transaction.
  /// 
  /// Only undoable actions may be added to a transaction.  An error will be 
  /// thrown if [action.canUndo] is `false`.
  void add(Action action) {
    if (action == null) {
      throw new ArgumentError('Action cannot be null');
    }
    if (!action.canUndo) {
      throw new ArgumentError(
          'Only undoable actions may be added to a transaction'); 
    }
    _arg.add(action);
  }
}

/// An asynchronous schedule of actions.
///
/// A schedule is a function that can be [call]ed with [Action]s.  The order 
/// of such calls is preserved in a history to allow for [undo] and [redo].  An 
/// action may be scheduled at any time; if the schedule [isIdle] then it will 
/// be called immediately, otherwise it will be queued to be called as soon 
/// as possible.  Methods to change the history such as [undo] and [redo] can 
/// _not_ be invoked when the schedule [isBusy].  This ensures that all queued 
/// actions are called and the schedule reaches an idle state before the history 
/// may be modified.  Each schedule is a state machine, and its [states] are 
/// observable as a stream; this provides a convenient means to connect a user 
/// interface to the history control methods.
class Schedule {
  
  /// A schedule is idle (not busy).
  static const String STATE_IDLE = 'IDLE';
  
  /// A schedule is busy executing a new action.
  static const String STATE_CALL = 'CALL';
  
  /// A schedule is busy flushing pending actions.
  static const String STATE_FLUSH = 'FLUSH';
  
  /// A schedule is busy performing a redo operation.
  static const String STATE_REDO = 'REDO';
  
  /// A schedule is busy performing an undo operation.
  static const String STATE_UNDO = 'UNDO';
  
  /// A schedule is busy performing a to operation.
  static const String STATE_TO = 'TO';
  
  /// A schedule has an error.
  static const String STATE_ERROR = 'ERROR';
  
  static const List<String> _STATES = 
      const [ STATE_IDLE, 
              STATE_CALL, 
              STATE_FLUSH, 
              STATE_REDO, 
              STATE_UNDO, 
              STATE_TO, 
              STATE_ERROR ];
  
  final _actions = new List<Action>();
  // Actions that are called while this schedule is busy are pending to be done.
  final _pending = new List<Action>();
  int _nextUndo = -1;
  String _currState = STATE_IDLE;
  var _err;
  var _stackTrace;
  
  /// Whether or not this schedule is busy performing another action.
  /// 
  /// This is always `true` when called from any continuations that are
  /// chained to Futures returned by methods on this schedule.
  /// This is also `true` if this schedule has an [error].
  /// 
  /// This is equivalent to `!isIdle`.
  bool get isBusy => !isIdle;
  
  /// Whether or not this schedule is in its [STATE_IDLE].
  /// 
  /// This is equivalent to `!isBusy`.
  bool get isIdle => _state == STATE_IDLE;
    
  /// Whether or not this schedule can be [clear]ed at the present time.
  bool get canClear => isIdle || hasError;
  
  bool get _canRedo => _nextUndo < _actions.length - 1;
  /// Whether or not the [redo] method may be called at the present time.
  bool get canRedo => isIdle && _canRedo;
  
  bool get _canUndo => _nextUndo >= 0;
  /// Whether or not the [undo] method may be called at the present time.
  bool get canUndo => isIdle && _canUndo;
  
  /// Whether or not this schedule has an [error].
  bool get hasError => _state == STATE_ERROR;
    
  /// The current error, if [hasError] is `true`.  
  /// 
  /// Calling [isBusy] on this schedule will return `true` for as long as this 
  /// schedule [hasError].  You may [clear] this schedule after dealing with the
  /// error condition in order to use it again.
  get error => _err;
  
  /// The current [error]'s stack trace, if [hasError] is `true` and a stack
  /// trace is available.
  get stackTrace => _stackTrace;
  
  void _error(e, [stackTrace]) {
    _err = e;
    _stackTrace = stackTrace;
    _state = STATE_ERROR;    
    _logError(e, stackTrace);
  }
  
  // The current state of this schedule.
  String 
    get _state => _currState;
    set _state(String nextState) {
      if (nextState != _currState && _currState != STATE_ERROR) {
        _currState = nextState;
        _logFine('--- enter state ---');
        if (_states.hasListener) _states.add(_currState);
      }
    }
    
  final _states = new StreamController<String>.broadcast();
  /// An observable stream of this schedule's state transitions.
  Stream<String> get states => _states.stream;
    
  /// Schedule the given [action] to be called.  
  /// 
  /// If this schedule [isIdle], the action will be called immediately.  Else, 
  /// the action will be deferred in order behind any other pending actions to 
  /// be called once this schedule reaches an idle state.
  Future call(Action action) {
    if (hasError) {
      _error(new StateError('Cannot call if Schedule.hasError.'));
      return new Future.error(error); 
    }
    if (_actions.contains(action) || _pending.contains(action)) {
      _error(new StateError('Cannot call $action >1 time on same schedule.'));
      return new Future.error(error);
    }
    if (isBusy) {
      _logFine('defer $action');
      _pending.add(action);
      return action._defer();
    }
    _state = STATE_CALL;
    return _do(action);
  }
  
  /// Clears this schedule if [canClear] is `true` at this time and returns
  /// `true` if the operation succeeds or `false` if it does not succeed.
  bool clear() {
    if (!canClear) return false;
    _logFine('clear');
    _actions.clear();
    _pending.clear();
    _nextUndo = -1;
    // Force the state back to STATE_IDLE even if we were in STATE_ERROR.
    if (_currState != STATE_IDLE) {
      _currState = STATE_IDLE;
      if (_states.hasListener) _states.add(_currState);
    }
    _err = null;
    _stackTrace = null;
    return true;
  }
  
  Future _do(action) {    
    var completer = new Completer();
    if (action.canUndo) {
      // Truncate the end of list (redo actions) when adding a new action.
      if (_nextUndo >= 0) _actions.removeRange(_nextUndo, _actions.length - 1);
      _actions.add(action);        
      _nextUndo++;
      _logFine('execute undoable $action [$_nextUndo]');
    } else {
      _logFine('execute non-undoable $action');
    }
    action._execute()
      .then((result) {
        _logFine('$action complete w/ $result');
        action._result = result;
        // Flush any pending action calls that were deferred as we did this 
        // action.  Also flush if we see STATE_ERROR, to ensure that pending
        // actions that were called prior to the error receive a completion.
        if (_state == STATE_CALL || _state == STATE_ERROR) {
          completer.future.whenComplete(_flush);        
        }
        // Complete the result before we flush pending and transition to idle.
        // This ensures 2 things:
        //    1) The continuations of the action see the state as the result of 
        //       this action and _not_ the state of further pending actions.
        //    2) The order of pending actions is preserved as the user is not
        //       able to undo or redo (busy == true) in continuations.
        completer.complete(result);        
      })
      .catchError((e, stackTrace) {
        _error(e, stackTrace);
        completer.completeError(e, stackTrace);
      });    
    return completer.future;    
  }
  
  Future _flush() {
    // If nothing is pending then complete immediate and go to STATE_IDLE.
    if (_pending.isEmpty) {
      _state = STATE_IDLE;
      return new Future.value();
    }
    _state = STATE_FLUSH;
    // Copy _pending actions to a new list to iterate because new actions 
    // may be added to _pending while we are iterating.
    final _flushing = _pending.toList();
    _pending.clear();
    _logFine('flushing ${_flushing.length} actions');
    return Future
      .forEach(_flushing, (action) => _do(action)) 
      .then((_) {        
        // If we get new _pending actions during flush we want to flush again.
        if (!_pending.isEmpty) {
          _logFine('new actions pending - flushing again');
          return _flush();
        } else {
          _logFine('flush complete');
          _state = STATE_IDLE;
        }
      })
      // The action will complete the error to its continuations, but we will 
      // also receive it here in order to transition to the error state.
      .catchError((e, stackTrace) => _error(e, stackTrace));
  }
      
  void _log(Level level, String message, [error, stackTrace]) {
    _logger.log(level, '[$_state]: $message', error, stackTrace);
  }
  
  void _logFine(String message) => _log(Level.FINE, message);
  void _logError(error, [stackTrace]) => 
      _log(Level.SEVERE, Error.safeToString(error), error, stackTrace);
  
  /// Redo the next action to be redone in this schedule, if any.
  /// 
  /// Completes `true` if an action was redone or else completes `false`.
  Future<bool> redo() { 
    var completer = new Completer<bool>();
    if(!_canRedo || !(_state == STATE_TO || _state == STATE_IDLE)) {
      _logFine('can not redo');
      completer.complete(false);
    } else {
      if (_state == STATE_IDLE) _state = STATE_REDO;
      final action = _actions[++_nextUndo];
      _logFine('execute $action [${_nextUndo-1}]');
      action._execute()
        .then((result) {
          _logFine('$action execute complete w/ $result');
          action._result = result;
          // Don't flush if we are in STATE_TO, it will flush when it is done.
          if (_state == STATE_REDO) completer.future.whenComplete(_flush);
          // Complete before we flush pending and transition to idle.
          // This ensures that continuations of redo see the state as the 
          // result of redo and _not_ the state of further pending actions. 
          completer.complete(true);          
        })
        .catchError((e, stackTrace) {
          _error(e, stackTrace);
          completer.completeError(e, stackTrace);
        });
    }
    return completer.future;
  }
  
  /// Undo or redo all ordered actions in this schedule until the given [action] 
  /// is done.  
  /// 
  /// The state of the schedule after this operation is equal to the state upon 
  /// completion of the given action. Completes `false` if any undo or redo 
  /// operations performed complete `false`, if the schedule does not contain 
  /// the given action, or if the schedule [isBusy].
  Future<bool> to(action) { 
    var completer = new Completer();    
    if (!_actions.contains(action) || 
        !(_state == STATE_TO || _state == STATE_IDLE)) {
      completer.complete(false);
    } else {      
      _state = STATE_TO;
      _to(action, completer);
    }
    return completer.future;
  }
  
  void _to(action, completer) {
    final handleError = (e, stackTrace) { 
      _error(e, stackTrace);
      completer.completeError(e, stackTrace); 
    };
    final int actionIndex = _actions.indexOf(action);
    if (actionIndex == _nextUndo) {
      completer.future.whenComplete(_flush);
      // Complete before we flush pending and transition to idle.
      // This ensures that continuations of 'to' see the state as the 
      // result of 'to' and _not_ the state of further pending actions.
      completer.complete(true);
    } else if (actionIndex < _nextUndo) {
      // Undo towards the desired action.
      undo()
        .then((success) {
          if (!success) {
            completer.complete(false);
          } else {
            _to(action, completer);
          }
        })
        .catchError(handleError);
    } else {
      // Redo towards the desired action.
      redo()
        .then((success) {
          if (!success) {
            completer.complete(false); 
          } else {
            _to(action, completer);
          }
        })
        .catchError(handleError);
    }
  }
  
  /// Undo the next action to be undone in this schedule, if any.
  /// Completes `true` if an action was undone or else completes `false`.
  Future<bool> undo() { 
    var completer = new Completer<bool>();
    if(!_canUndo || !(_state == STATE_TO || _state == STATE_IDLE)) {
      _logFine('can not undo');
      completer.complete(false);
    } else {
      if (_state == STATE_IDLE) _state = STATE_UNDO;      
      final action = _actions[_nextUndo--];
      _logFine('unexecute $action [${_nextUndo+1}]');
      action._unexecute()
        .then((_) {
          _logFine('$action unexecute complete');
          // Don't flush if we are in STATE_TO, it will flush when it is done.
          if (_state == STATE_UNDO) completer.future.whenComplete(_flush);
          // Complete before we flush pending and transition to idle.
          // This ensures that continuations of undo see the state as the 
          // result of undo and _not_ the state of further pending actions. 
          completer.complete(true);          
        })
        .catchError((e, stackTrace) {
          _error(e, stackTrace);
          completer.completeError(e, stackTrace);
        });
    }
    return completer.future;
  }
  
  /// Wait for this schedule to reach the given [state].
  /// 
  /// Completes on the next transition to the given state, or immediately if the 
  /// state is the current state of this schedule.  Completes an [ArgumentError]
  /// if the given [state] is not valid.
  Future<String> wait(String state) {
    if (!_STATES.contains(state)) {
      return new Future.error(
          new ArgumentError('$state is not a valid state.'));
    }
    if (_state == state) {
      return new Future.value(_state);  
    }
    return states.firstWhere((s) => s == state);
  }
}
