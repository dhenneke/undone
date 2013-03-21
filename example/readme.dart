
// This library contains the example code used in the README file.
library readme;

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
  // Undo and Redo.
  //----------------------------------------------------------------------------  
  
  // Run undo / redo in a sequence of steps.
  // In a real application you will typically bind user interface controls to
  // undo and redo, and those controls will be enabled only in STATE_IDLE.  
  // See our 'nudge' example for a more real-world usage.
  int step = 0;  
  schedule.states.listen((state) {
    if (state == Schedule.STATE_IDLE) {
      switch(step) {
        case 0:
          // Undo your action.
          undo().then((_) => print('${map["value"]}')); // prints '42'
          break;
        case 1: 
          // Redo your action.
          redo().then((_) => print('${map["value"]}')); // prints '43'
          break;
      }
      step++;
    }
  });
}
