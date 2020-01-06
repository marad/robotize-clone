import 'dart:ffi';
import 'dart:io';
import 'winapi.dart' as winapi;
import 'keyboard.dart';

class Input {
  static var keyPressDuration = Duration(milliseconds: 20);
  static void send(String toSend) {
    sendKeys(stringToKeys(toSend));
  }


  static List<KeyEvent> stringToKeys(String toSend, {bool raw = false}) {
    if (!raw) {
      print("Only raw mode is currently supported");
    }

    var keys = <KeyEvent>[];
    for(int i=0; i < toSend.length; i++) {
      var char = toSend[i];
      if (_specialKeysWithoutShift.contains(char)) {
        keys.add(KeyEvent(char, keyMap[char]));
      } else if (_specialKeysShiftMap.keys.contains(char)) {
        keys.add(KeyEvent(char, keyMap[_specialKeysShiftMap[char]], shift: true));
      } else {
        keys.add(KeyEvent(char, keyMap[char.toUpperCase()],
        shift: char == char.toUpperCase()));
      }
    }
    return keys;
  }

  static void sendKeys(List<KeyEvent> keyEvents) {
    keyEvents.forEach((event) {
      event.modifiers.forEach((name) => sendKeyDown(keyMap[name]));
      if (event.down) {
        sendKeyDown(event.keyCode);
      }

      sleep(keyPressDuration);

      if (event.up) {
        sendKeyUp(event.keyCode);
      }
      event.modifiers.forEach((name) => sendKeyUp(keyMap[name]));
    });
  }

  static void sendKeyDown(int virtualKeyCode) {
    winapi.keybd_event(
        virtualKeyCode, 
        winapi.MapVirtualKeyW(virtualKeyCode, winapi.MAPVK_VK_TO_VSC), 
        winapi.KEYEVENTF_EXTENDEDKEY, 
        nullptr);
  }

  static void sendKeyUp(int virtualKeyCode) {
    winapi.keybd_event(
        virtualKeyCode, 
        winapi.MapVirtualKeyW(virtualKeyCode, winapi.MAPVK_VK_TO_VSC), 
        winapi.KEYEVENTF_EXTENDEDKEY | winapi.KEYEVENTF_KEYUP, 
        nullptr);
  }

  static var _specialKeysWithoutShift = "[];',./`\\=-";
  static var _specialKeysShiftMap = {
    "~": "`",
    "!": "1",
    "@": "2",
    "#": "3",
    "\$": "4",
    "%": "5",
    "^": "6",
    "&": "7",
    "*": "8",
    "(": "9",
    ")": "0",
    "_": "-",
    "+": "=",
    "{": "[",
    "}": "]",
    "|": "\\",
    ":": ";",
    "\"": "'",
    "<": ",",
    ">": ".",
    "?": "/",
  };
}
