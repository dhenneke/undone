
// This library contains the example code used in the README file.
library readme;

import 'dart:math' as math;
import 'package:undone/undone.dart';

main() {  
  //----------------------------------------------------------------------------
  // Define an Action.
  //----------------------------------------------------------------------------
  
  // A map object that our action will modify.
  var map = { 'value' : 42 }; 
  
  // A 'Do' function to increment the 'value' key of a given map.  
  Do increment = (a) => ++a['value'];
  
  // An 'Undo' function to decrement the 'value' key of a given map.
  Undo decrement = (a, _) => --a['value'];    
  
  // An action to bind the increment / decrement functions to our 'map' object.
  var action = new Action(map, increment, decrement);
  
  //----------------------------------------------------------------------------
  // Schedule an Action.
  //----------------------------------------------------------------------------
  
  // Call your action, and listen for the result (if you want) - its easy!
  action().then((result) => print('$result')); // prints '43'
  
  //----------------------------------------------------------------------------
  // Schedule a Transaction.
  //----------------------------------------------------------------------------
    
  // Define another action to determine the square of the map's 'value'
  Do square = (a) => a['value'] = a['value'] * a['value'];
  Undo squareRoot = (a, _) => a['value'] = math.sqrt(a['value']);
  var action2 = new Action(map, square, squareRoot);
  
  // Schedule a transaction that contains both actions (increment then square).
  transact(() {
      action();
      action2();
  }).then((_) => print('${map["value"]}')); // prints '1936'
  
  //----------------------------------------------------------------------------
  // Undo and Redo.
  //----------------------------------------------------------------------------  
  
  // See 'nudge.dart' for undo and redo bindings.  
}
