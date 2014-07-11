## An Asynchronous Schedule

Most of the implementations of undo and redo that I have seen have been purely
synchronous.  Undone deviates from that norm.  User interfaces need to remain
responsive, which means expensive work needs to be offloaded from the main ui 
thread.  In Dart there can be only one... thread per isolate.  This is true in 
any Dart environment, not just the browser.  Undone is written to use the 
facilities provided by the standard `dart:async` library.

Authors of synchronous undo are likely to claim that ui actions should be very 
fast and that there is no need to perform them asynchronously.  I agree 
wholeheartedly with that principle, but my experience has been that you will 
inevitably encounter an expensive operation that you need to wrap in an undoable
action.  Also, if you start to consider using your undo system for something 
_other_ than ui actions, you will very likely encounter things that are 
asynchronous in nature.  We are, after all, in the browser here!

Okay, so we may need to do some actions asynchronously, what are the 
ramifications?  The thing about async code is that as soon as one thing is 
async, it tends to have a ripple effect on everything around it.  This holds 
true for undo.  Let's look closer at how undone works to understand.

One of the core concepts in undo and redo is that of a history list, also known
as an undo stack, etc... This is a data structure that keeps track of your 
undoable actions and the order in which they are done.  In a sychronous world, 
the code to manage such a data structure can be quite minimal.  When things go
async, it is another beast.  Undone is designed around the notion of a 
`Schedule`.

The goal of the schedule is to minimize the impact of the async world on the
user of the undo library.  Just like how the word 'schedule' is both a noun and 
a verb, the `Schedule` type is both a class and a function.  As a class, it is 
the type that contains the history of actions and as a function, it can be 
called to do an action.

Undone provides a top-level `schedule]` getter.  Actions are also functions, and 
if you call an action it will call itself on the top-level schedule.  That 
probably sounds complicated to you now, but the end result is that it makes your 
life easy.  Let's look at some fictional example code:

```dart
incrementAsync();
square();
```

Above, we assume that we have two action instances named `incrementAsync` and 
`square` that perform calculations on a shared argument.  Since they are 
functions, we can `call()` them just like any Dart function.  The first 
action `incrementAsync` will perform its work asynchronously, and the second 
action `square` will perform its work synchronously.  Both calls are sent to the 
top-level schedule, and `square` will be queued internally while 
`incrementAsync` executes, and then executed after.  In a synchronous 
implementation, `square` would likely be executed immediately when it is called, 
which is _during_ the executon of `incrementAsync`.  The result would be a 
corrupt history list, an incorrect calculation, and any number of other 
problems.  The asynchronous schedule allows this to be a valid program, and 
abstracts away a lot of the pain.

If I've managed to convince you of _why_ I've built in support for async 
actions, I hope that you may now appreciate how the schedule helps alleviate
some of the pain.  The schedule is implemented as a state machine; as a user of
the schedule you should not need to care about that often.  Actions can be
scheduled at any time (during any state) and the schedule will take care of 
making sure things are done in the right order.  Much of the API returns 
futures, and this allows you to chain continuations onto method calls.  The
schedule will make sure your continuations happen at all the right times.  Let's
look again at our fictional example:

```dart
var arg = { 'value' : 42};
var incrementAsync = new Increment(arg);
var square = new Square(arg);
...
incrementAsync().then((result) => print('$result'));
square.then((result) => print('$result'));
```

We see now that `incrementAsync` and `square` are both action instances that we
construct from custom action types.  Both instances take the same argument, and
let's assume that they are both implemented to manipulate the argument's 'value'
in a manner their names suggest.  When the above program is run, the printed
output will be:

```
43
1849
```

Everything happens at the time you naturally expect.  You may call new actions
from within the continuations and the schedule will make sure to execute them in 
the order you call them.  

The schedule will always report that it `isBusy` in a continuation, or at any
time when it is not idle.  Although you may always call a new action on a 
schedule at any time, it is important to know that you may _not_ call methods
such as `undo` that modify the schedule if it `isBusy`.  In the above example,
we cannot allow the continuation on `incrementAsync` to perform an `undo`, 
because we need to make sure that the `square` gets done first.

## Binding to Undo and Redo

Most of the code in your program will only care about calling actions, and the 
schedule will make sure to execute them in the order you call them.

Invoking `undo` and `redo` is really an entirely separate path in your code.
Typically, you will want to bind these methods to user gestures such as the 
keyboard input `ctrl+z` and `ctrl+y`:

```dart
// Bind undo / redo to keyboard events.
document.onKeyUp.listen((e) {    
  if (e.ctrlKey) {
    if (e.keyCode == KeyCode.Z) {
      undo();
    } else if (e.keyCode == KeyCode.Y) {
      redo();
    }
  }
});
```

The `Schedule` type also provides getters for `canUndo` and `canRedo`.  If you 
are using a data-binding framework, you can use these directly in bindings to 
enable button controls, etc...  If you don't have data-binding, then this is one 
scenario when you may want to observe the `onStateChange` stream of a schedule, 
in order to refresh your controls:

```dart
// Listen to state changes in the schedule to refresh the ui.
schedule.onStateChange.listen((state) {
  if (state == Schedule.STATE_IDLE) {
    undoButton.disabled = !schedule.canUndo;
    redoButton.disabled = !schedule.canRedo;
  }
});
```

## Transactions Made Simple

Another common scenario is to _merge_ together more than one action into a
`Transaction`.  All of the actions in the transaction will be done and undone 
together as a single 'atomic' unit.  This library provides an easy way to build 
transactions using the top-level `transact` method:

```dart
transact(() {
  cut();
  paste();
});
```

In the example above, the calls to the actions `cut` and `paste` occur within
an anonymous closure.  The `transact` function will invoke this closure, and all 
actions that are called within its scope are added to a new `Transaction` 
object.  After the anonymous function returns, the `Transaction` will be called 
on the top-level schedule.  Cut and paste is a real world example, as you 
normally want these actions to be executed together as one.  If something goes 
awry during paste, you want to rollback to the initial state by undoing the cut.

In addition to the convenience of the `transact` function, you can also create
`Transaction` objects yourself and add actions to them imperatively.  In this 
case it is your call when to schedule the transaction.
