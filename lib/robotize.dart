export 'package:robotize/src/windows.dart';
export 'package:robotize/src/input.dart';
export 'package:robotize/src/hotkeys.dart';

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:robotize/src/hotkeys.dart';
import 'package:robotize/src/winapi.dart' as winapi;

class Robotize {
  static void start() {
    Hotkey.init();

    var msg = allocate<winapi.MSG>();

    while(true) { 
      var result = winapi.GetMessage(msg, nullptr, 0, 0);

      if (result > 0) {
        winapi.TranslateMessage(msg);
        winapi.DispatchMessage(msg);
      } else if (result < 0) {
        // TODO: error handling
        print('Some error!');
      } else if (result == 0) {
        // TODO: cleanup hooks
        break;
      }
    }
  }
}