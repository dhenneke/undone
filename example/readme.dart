
// This library contains the example code used in the README file.
library readme;

import 'dart:math' as math;
import 'package:undone/undone.dart';

main() {  
  //----------------------------------------------------------------------------
  // Build an Action from Functions
  //----------------------------------------------------------------------------
  
  // Actions bind a 'Do' functon and an 'Undo' function together with arguments.
  Do _increment = (a) => ++a['value'];
  Undo _decrement = (a, _) => --a['value'];  
  var map = { 'value' : 42 }; 
  var increment = new Action(map, _increment, _decrement);
  
  //----------------------------------------------------------------------------
  // Schedule an Action.
  //----------------------------------------------------------------------------
  
  // Call your action, and listen for the result (if you want) - its easy!
  increment().then((result) => print('$result')); // prints '43'
  
  //----------------------------------------------------------------------------
  // Schedule a Transaction.
  //----------------------------------------------------------------------------
    
  var square = new Power2(map);
  
  transact(() {
      increment();
      square();
  }).then((_) => print('${map["value"]}')); // prints '1936'
  
  //----------------------------------------------------------------------------
  // Undo and Redo.
  //----------------------------------------------------------------------------  
  
  // See 'nudge.dart' for undo and redo bindings.  
}

//------------------------------------------------------------------------------
// Define a Custom Action Type.
//------------------------------------------------------------------------------

// Use custom actions when you want your own type.
class Power2 extends Action {  
  static _square(a) => a['value'] = a['value'] * a['value'];  
  static _squareRoot(a, r) => a['value'] = math.sqrt(a['value']);  
  Power2(map): super(map, _square, _squareRoot);  
}
