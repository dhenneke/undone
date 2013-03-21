# Undone

A little undo-redo library.

[![Build Status](https://drone.io/github.com/rmsmith/undone/status.png)][badge]

## Usage

### Define an Action

```dart
// A map object that our action will modify.
var map = { 'value' : 42 }; 
  
// A 'Do' function to increment the 'value' key of a given map.  
Do increment = (a) => ++a['value'];
  
// An 'Undo' function to decrement the 'value' key of a given map.
Undo decrement = (a, _) => --a['value'];    
  
// An action to bind the increment / decrement functions to our 'map' object.
var action = new Action(map, increment, decrement);  
```

### Schedule an Action

```dart
// Call your action, and listen for the result (if you want) - its easy!
action().then((result) => print('$result')); // prints '43'
```

### Schedule a Transaction

```dart
// Another action to square the 'value' of a given map.
Do square = (a) => a['value'] = a['value'] * a['value'];
Undo squareRoot = (a, _) => a['value'] = math.sqrt(a['value']);
var action2 = new Action(map, square, squareRoot);
  
// Schedule a transaction that contains both actions (increment then square).
transact(() {
    action();
    action2();
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

_Undone uses the MIT license as described in the LICENSE file, and follows
[semantic versioning][]._

[badge]: https://drone.io/github.com/rmsmith/undone/latest
[semantic versioning]: http://semver.org/
