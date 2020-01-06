import 'dart:ffi';
import 'winapi.dart' as winapi;
import 'keyboard.dart';


class Hotkey {
  static var _hotkeys = <String, Function> {};

  static void add(String hotkey, Function callback) => _hotkeys[hotkey] = callback;
  static void remove(String hotkey) => _hotkeys.remove(hotkey);

  static int _keybdHookProc(int code, Pointer<Uint64> wParam, Pointer<Int64> lParam) {
    var event = wParam.address;
    Pointer<winapi.KBDLLHOOK> dataPtr = lParam.cast();
    var data = dataPtr.ref;

    var keyName = keyMap.entries.firstWhere((entry) => entry.value == data.vkCode, orElse: () => null);
    // TODO: encoding modifiers into string
    if (keyName != null && _hotkeys.containsKey(keyName.key)) {
      if (event == winapi.WM_KEYDOWN) {
        _hotkeys[keyName.key]();
      }
      return 1;
    } else {
      return winapi.CallNextHookEx(nullptr, code, wParam, lParam);
    }
  }

  static void init() {
    var callback = Pointer.fromFunction<winapi.KeyboardProc>(Hotkey._keybdHookProc, 0);
    var hook = winapi.SetWindowsHookExW(winapi.WH_KEYBOARD_LL, callback, nullptr, 0);
    if (hook == nullptr) {
      // TODO: handle error
      print('couldnt register the hook');
    } else {
      print('Hook registered');
    }
  }
}