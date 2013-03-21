
// This library contains the example code used in the README file.
library readme;

import 'dart:math' as math;
import 'package:undone/undone.dart';

// Use custom actions when you want your own type.
class Square extends Action {  
  static _square(a) => a['value'] = a['value'] * a['value'];  
  static _squareRoot(a, r) => a['value'] = math.sqrt(a['value']);  
  Square(map): super(map, _square, _squareRoot);  
}

main() {  
  //----------------------------------------------------------------------------
  // Create an Action from Functions.
  //----------------------------------------------------------------------------
  
  // An argument for our undoable actions.
  var map = { 'value' : 42 };
  
  // Actions bind a 'Do' functon and an 'Undo' function together with arguments.
  Do _increment = (a) => ++a['value'];
  Undo _decrement = (a, _) => --a['value'];     
  var increment = new Action(map, _increment, _decrement);
  
  //----------------------------------------------------------------------------
  // Create a Custom Action Type.
  //----------------------------------------------------------------------------
  
  var square = new Square(map);
  
  //----------------------------------------------------------------------------
  // Schedule an Action.
  //----------------------------------------------------------------------------
  
  // Call your action, and listen for the result (if you want) - its easy!
  increment().then((result) => print('$result')); // prints '43'
  
  //----------------------------------------------------------------------------
  // Schedule a Transaction.
  //----------------------------------------------------------------------------
    
  // Call actions in a transaction - they'll be done and undone together!
  transact(() {
      increment();
      square();
  }).then((_) => print('${map["value"]}')); // prints '1936'
  
  //----------------------------------------------------------------------------
  // Undo and Redo.
  //----------------------------------------------------------------------------  
  
  // See 'nudge.dart' for undo and redo bindings.  
}
