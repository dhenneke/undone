
/// Actions that use `dart:mirrors`.
library mirrors;

import 'dart:mirrors';
import 'undone.dart';

/// An [Action] to set a field of an [Object].
///
/// This action uses synchronous mirror reflection to do and undo its operation.
class SetField extends Action {
  
  static Object _do(List args) {
    final mirror = args[0];
    final fieldName = args[1];
    final arg = args[2];
    final oldArg = mirror.getField(fieldName).reflectee;
    mirror.setField(fieldName, arg);    
    return oldArg;
  }
  
  static void _undo(List args, Object oldArg) {
    final mirror = args[0];
    final fieldName = args[1];
    mirror.setField(fieldName, oldArg);
  }
  
  /// Constructs a new action to set the field with the given [fieldName] on the
  /// object instance reflected by the given [mirror] to the given [arg].
  SetField(InstanceMirror mirror, Symbol fieldName, Object arg) 
    : super([mirror, fieldName, arg], _do, _undo);
}
