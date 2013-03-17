library nudge;

import 'dart:async';
import 'dart:html';
import 'package:undone/undone.dart';

/// Object to nudge around the canvas.
class Box {  
  /// The current top-left point of this box.
  num x, y;
  
  /// Construct a new box with the given top-left coordinates.
  Box(this.x, this.y);
  
  /// Renders this box at its current point.
  render(CanvasRenderingContext2D ctx) {
    ctx.setFillColorRgb(255, 0, 0);
    ctx.fillRect(x, y, 10, 10);
  }
}

/// Custom action to nudge a box a given distance.
class Nudge extends Action {
  // Directions for box nudging.
  static const int UP = 0;
  static const int DOWN = 1;
  static const int LEFT = 2;
  static const int RIGHT = 4;

  static List _do(List args) {
    final box = args[0];
    final distance = args[1];   
    final direction = args[2];
    // Save the box's current position.
    final oldPosition = [box.x, box.y];
    // Move the box by the given distance in the given direction.
    switch(direction) {
      case UP:    box.y -= distance; break;
      case DOWN:  box.y += distance; break;
      case LEFT:  box.x -= distance; break;
      case RIGHT: box.x += distance; break;
    }
    // Return the old position as the result, it will be passed to undo.
    return oldPosition;
  }
  
  static void _undo(List args, List oldPosition) {
    final box = args[0];
    // Restore the box's old position.
    box.x = oldPosition[0];
    box.y = oldPosition[1];
  }
  
  Nudge(Box box, num distance, int direction)
    : super([box, distance, direction], _do, _undo);
}

Box box;

main() {
  document.onKeyUp.listen((e) {    
    if (e.ctrlKey) {
      if (e.keyCode == KeyCode.Z)           undo();
      else if (e.keyCode == KeyCode.Y)      redo();
    } else {
      if (e.keyCode == KeyCode.UP)          new Nudge(box, 10, Nudge.UP)();
      else if (e.keyCode == KeyCode.DOWN)   new Nudge(box, 10, Nudge.DOWN)(); 
      else if (e.keyCode == KeyCode.LEFT)   new Nudge(box, 10, Nudge.LEFT)();
      else if (e.keyCode == KeyCode.RIGHT)  new Nudge(box, 10, Nudge.RIGHT)();
    }
  });
  
  final undoButton = query('#undo');
  final redoButton = query('#redo');
  undoButton.onClick.listen((e) => undo());
  redoButton.onClick.listen((e) => redo());
  
  // Listen to state changes in the schedule to refresh the ui.
  schedule.states.listen((state) {
    if (state == Schedule.STATE_IDLE) {
      undoButton.disabled = !schedule.canUndo;
      redoButton.disabled = !schedule.canRedo;
      render();
    }
  });
  
  // Construct a box initially centered (approximately) on the canvas.
  var canvas = document.query("#content") as CanvasElement;
  box = new Box(canvas.width / 2, canvas.height / 2);  
  // Render the initial state.
  render();
}

render() {
  var canvas = document.query("#content") as CanvasElement;
  var ctx = canvas.getContext("2d");
  // Clear the canvas.
  ctx.setFillColorRgb(200, 200, 100);
  ctx.fillRect(0, 0, canvas.width, canvas.height);  
  // Render the block.
  box.render(ctx); 
}
