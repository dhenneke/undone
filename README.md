# Undone

A library for undo and redo.

[![Build Status](https://drone.io/github.com/rmsmith/undone/status.png)][badge]

## Usage

### Create an Action from Functions

```dart
// An argument for our undoable actions.
var map = { 'value' : 42 };
  
// Actions bind a 'Do' functon and an 'Undo' function together with arguments.
Do _increment = (a) => ++a['value'];
Undo _decrement = (a, r) => --a['value'];     
var increment = new Action(map, _increment, _decrement);
```

### Create a Custom Action Type

```dart
// Use custom actions when you want your own type.
class Square extends Action {  
  static _square(a) => a['value'] = a['value'] * a['value'];  
  static _squareRoot(a, r) => a['value'] = math.sqrt(a['value']);  
  Square(map): super(map, _square, _squareRoot);  
}

var square = new Square(map);
```

### Do an Action

```dart
// Call your action, and listen for the result (if you want) - its easy!
increment().then((result) => print('$result')); // prints '43'
```

### Do a Transaction

```dart  
// Call actions in a transaction - they'll be done and undone together!
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

## Read the Article

Learn more about the design decisions by reading this [article][].

_Undone uses the MIT license as described in the [LICENSE][license] file, and 
follows [semantic versioning][]._

[article]: http://futureperfect.info/2013/03/22/undone-not-a-song-about-sweaters.html
[badge]: https://drone.io/github.com/rmsmith/undone/latest
[license]: https://github.com/rmsmith/undone/blob/master/LICENSE
[nudge]: https://github.com/rmsmith/undone/blob/master/example/nudge.html
[readme]: https://github.com/rmsmith/undone/blob/master/example/readme.dart
[semantic versioning]: http://semver.org/
