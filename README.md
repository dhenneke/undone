# Undone

A little undo-redo library.

[![Build Status](https://drone.io/github.com/rmsmith/undone/status.png)][badge]

## Usage

### Build an Action from Functions

```dart
// An argument for our undoable actions.
var map = { 'value' : 42 };
  
// Actions bind a 'Do' functon and an 'Undo' function together with arguments.
Do _increment = (a) => ++a['value'];
Undo _decrement = (a, _) => --a['value'];     
var increment = new Action(map, _increment, _decrement);
```

### Define a Custom Action Type

```dart
// Use custom actions when you want your own type.
class Power2 extends Action {  
  static _square(a) => a['value'] = a['value'] * a['value'];  
  static _squareRoot(a, r) => a['value'] = math.sqrt(a['value']);  
  Power2(map): super(map, _square, _squareRoot);  
}

var square = new Power2(map);
```

### Schedule an Action

```dart
// Call your action, and listen for the result (if you want) - its easy!
increment().then((result) => print('$result')); // prints '43'
```

### Schedule a Transaction

```dart  
transact(() {
    increment();
    square();
}).then((_) => print('${map["value"]}')); // prints '1936'
```

### Undo and Redo

```dart
// Bind undo / redo to keyboard events.
document.onKeyUp.listen((e) {    
  if (e.ctrlKey) {
    if (e.keyCode == KeyCode.Z)           undo();
    else if (e.keyCode == KeyCode.Y)      redo();
  }
});
```

## Run the Examples

The code above can be found [here][readme].  For more fun, try to [nudge][] a 
box around a canvas - its undoable!

_Undone uses the MIT license as described in the LICENSE file, and follows
[semantic versioning][]._

[badge]: https://drone.io/github.com/rmsmith/undone/latest
[nudge]: https://github.com/rmsmith/undone/blob/master/example/nudge.html
[readme]: https://github.com/rmsmith/undone/blob/master/example/readme.dart
[semantic versioning]: http://semver.org/
