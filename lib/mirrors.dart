
/// Actions that use `dart:mirrors`.
library mirrors;

import 'dart:mirrors';
import 'undone.dart';

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
  
  SetField(Object o, Symbol fieldName, Object arg) 
    : super([reflect(o), fieldName, arg], _do, _undo);
}
