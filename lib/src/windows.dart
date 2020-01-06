import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'winapi.dart' as winapi;
import 'keyboard.dart';

// Funkcje do zaimplementowania w pierwszej kolejnosci
// [x] Pobranie aktywnego okna (GetActiveWindow)
// [x] Aktywowanie Okna (SetActiveWindow / SetForegroundWindow)
// [x] Wysłanie wciśnięć klawiszy (SendInput)
// [ ] Wysłanie kliknięcia
// [ ] - kliknięcie relatywnie do ekranu
// [ ] - kliknięcie relatywnie do okna (ScreenToClient / ClientToScreen)
// [ ] Czytanie clipboardu / Zapisywanie do clipboardu
// [x] Szukanie Okna (FinwWindowExA)
// [x] - Szukanie po ID
// [x] - Szukanie po tytule
// [x] - Szukanie po klasie
// [ ] - Szukanie po nazwie programu
// [ ] Oczekiwanie aż okno będzie aktywne
// [ ] Oczekiwanie aż okno przestanie być aktywne
// [ ] Oczekiwanie aż okno zostanie zamknięte
// [x] Maxymalizowanie / minimalizowanie okna
// [x] Zamknięcie okna
// [ ] Ustawianie flag (np. AlwaysOnTop itp.) (AHK: WinSet)
// [x] Ukrycie / Pokazanie okna
// [x] RegisterHotkey / UnregisterHotkey
// [ ] DllCall?

// ================================================================================
//
// Querying Window Info
//
// ================================================================================

class WindowId {
  final int windowId;
  WindowId(this.windowId);
  factory WindowId.fromAddress(int address) => WindowId(address);
  factory WindowId.fromPointer(Pointer hwnd) => WindowId(hwnd.address);
  Pointer asPointer() => Pointer.fromAddress(windowId);
}

class WindowInfo {
  final WindowId id;
  final String title;
  final String className;

  WindowInfo(this.id, this.title, this.className);

  @override
  String toString() {
    return "ID: ${id.windowId}, class: $className, title: $title";
  }
}

class WindowQuery {
  final WindowId windowId;
  final Pattern titleMatcher;
  final Pattern classMatcher;
  // final Pattern exeNameMatcher;
  final bool onlyVisible;

  WindowQuery(
      {this.windowId,
      this.titleMatcher,
      this.classMatcher,
      // this.exeNameMatcher,
      this.onlyVisible = true});

  bool windowMatches(WindowInfo candidate) {
    var windowIdMatches = this.windowId != null
        ? this.windowId.windowId == candidate.id.windowId
        : true;
    return windowIdMatches &&
        _titleMatches(candidate.title) &&
        _classMatcher(candidate.className);
  }

  bool _titleMatches(String title) => _filterMatch(titleMatcher, title);
  bool _classMatcher(String title) => _filterMatch(classMatcher, title);

  bool _filterMatch(Pattern pattern, String toMatch) {
    if (pattern == null) {
      return true;
    }
    return pattern.allMatches(toMatch).length > 0;
  }
}

WindowId getActiveWindow() =>
    WindowId.fromPointer(winapi.GetForegroundWindow());

WindowInfo getWindowInfo(WindowId id) {
  var buffer = allocate<Uint16>(count: 257);
  var readChars = winapi.GetClassNameW(id.asPointer(), buffer, 257);
  String className = _bufToString(buffer, readChars);
  free(buffer);
  return WindowInfo(id, getWindowText(id), className);
}

String _bufToString(Pointer<Uint16> buffer, int length) {
  List<int> classChars = buffer.asTypedList(length);
  return String.fromCharCodes(classChars);
}


/// Returns text from provided window or control.
String getWindowText(WindowId id) {
  var hwnd = id.asPointer();
  var length = winapi.GetWindowTextLengthA(hwnd);
  var buffer = allocate<Uint16>(count: length + 1);
  var readChars = winapi.GetWindowTextW(hwnd, buffer, length + 1);
  List<int> chars = buffer.asTypedList(readChars);
  free(buffer);
  return String.fromCharCodes(chars);
}

class _WindowCollector extends Struct {
  @Uint32()
  int capacity;
  @Uint32()
  int numWindows;
  Pointer<Uint32> windows;
  @Uint32()
  int onlyVisible;

  factory _WindowCollector.allocate(int capacity, bool onlyVisible) =>
      allocate<_WindowCollector>().ref
        ..capacity = capacity
        ..numWindows = 0
        ..onlyVisible = onlyVisible ? 1 : 0
        ..windows = allocate<Uint32>(count: capacity);

  void addWindow(int windowId) {
    // TODO: if capacity is reached - allocate more and copy
    windows[numWindows++] = windowId;
  }
}

int _windowFoundCallback(Pointer hwnd, Pointer lparam) {
  _WindowCollector reducer = lparam.cast<_WindowCollector>().ref;

  if (reducer.onlyVisible == 1 &&
      (winapi.GetWindowLongA(hwnd, winapi.GWL_STYLE) & winapi.WS_VISIBLE) == 0) {
    return 1;
  }

  reducer.addWindow(hwnd.address);
  return 1;
}


/// Lists windows. If query is not provided, lists only visible windows.
List<WindowInfo> listWindows({WindowQuery query}) {
  if (query != null && query.windowId != null) {
    // find and examine only one window
    var info = getWindowInfo(query.windowId);
    if (query.windowMatches(info)) {
      return [info];
    } else {
      return [];
    }
  } else {
    // find and filter all windows
    var reducer = _WindowCollector.allocate(
        500, query != null ? query.onlyVisible : true);
    var func = Pointer.fromFunction<winapi.EnumWindowsCallback>(_windowFoundCallback, 0);
    winapi.EnumWindows(func, reducer.addressOf);
    var result = <WindowId>[];
    for (var i = 0; i < reducer.numWindows; i++) {
      var id = reducer.windows.elementAt(i).value;
      var windowId = WindowId.fromAddress(id);
      result.add(windowId);
    }
    if (query != null) {
      return result.map(getWindowInfo).where(query.windowMatches).toList();
    } else {
      return result.map(getWindowInfo).toList();
    }
  }
}

WindowInfo findWindow(WindowQuery query) {
  var windows = listWindows(query: query);
  if (windows.length > 0) {
    return windows.first;
  } else {
    return null;
  }
}

// ================================================================================
//
// Window State Management
//
// ================================================================================

bool activateWindow(WindowId id) {
  var window_c = id != null ? id.asPointer() : nullptr;
  var isIconic = winapi.IsIconic(window_c);
  if (isIconic > 0) {
    winapi.ShowWindow(window_c, winapi.SW_RESTORE);
  }
  winapi.SetActiveWindow(window_c);
  var ret = winapi.SetForegroundWindow(window_c);
  return ret > 0;
}

/// Returns true if window was previously visible.
bool showWindow(WindowId id) {
  return winapi.ShowWindow(id.asPointer(), winapi.SW_SHOW) > 0;
}

/// Returns true if window was previously visible.
bool hideWindow(WindowId id) {
  return winapi.ShowWindow(id.asPointer(), winapi.SW_HIDE) > 0;
}

/// Returns true if window was previously visible.
bool maximizeWindow(WindowId id) {
  return winapi.ShowWindow(id.asPointer(), winapi.SW_MAXIMIZE) > 0;
}

/// Returns true if window was previously visible.
bool minimizeWindow(WindowId id) {
  return winapi.ShowWindow(id.asPointer(), winapi.SW_MINIMIZE) > 0;
}

bool restoreWindow(WindowId id) {
  return winapi.ShowWindow(id.asPointer(), winapi.SW_RESTORE) > 0;
}

void quitWindow(WindowId id) {
  sendMessage(id, 0x0012, 0, 0);
  // return winapi.DestroyWindow(id.asPointer()) > 0;
}


// ================================================================================
//
// Posting messages and keyboard input
//
// ================================================================================

int postMessage(WindowId id, int msg, int wparam, int lparam) {
  var wparam_c =  allocate<Uint64>();
  var lparam_c = allocate<Int64>();
  var result = winapi.PostMessageW(id.asPointer(), msg, wparam_c, lparam_c);
  free(wparam_c);
  free(lparam_c);
  return result;
}

int sendMessage(WindowId id, int msg, int wparam, int lparam) {
  var wparam_c =  allocate<Uint64>();
  var lparam_c = allocate<Int64>();
  var result = winapi.PostMessageW(id.asPointer(), msg, wparam_c, lparam_c);
  free(wparam_c);
  free(lparam_c);
  return result;
}

var keyPressDuration = Duration(milliseconds: 20);

void sendInput(String toSend) {
  sendKeys(stringToKeys(toSend));
}

List<KeyEvent> stringToKeys(String toSend, {bool raw = false}) {
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

void sendKeys(List<KeyEvent> keyEvents) {
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

void sendKeyDown(int virtualKeyCode) {
  winapi.keybd_event(
      virtualKeyCode, 
      winapi.MapVirtualKeyW(virtualKeyCode, winapi.MAPVK_VK_TO_VSC), 
      KEYEVENTF_EXTENDEDKEY, 
      nullptr);
}

void sendKeyUp(int virtualKeyCode) {
  winapi.keybd_event(
      virtualKeyCode, 
      winapi.MapVirtualKeyW(virtualKeyCode, winapi.MAPVK_VK_TO_VSC), 
      KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 
      nullptr);
}

var _specialKeysWithoutShift = "[];',./`\\=-";
var _specialKeysShiftMap = {
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

const INPUT_MOUSE = 0;
const INPUT_KEYBOARD = 1;
const INPUT_HARDWARE = 2;

const KEYEVENTF_EXTENDEDKEY = 0x0001;
const KEYEVENTF_KEYUP = 0x0002;
const KEYEVENTF_UNICODE = 0x0004;
const KEYEVENTF_SCANCODE = 0x0008;

class KeyboardInput extends Struct {
  @Uint64() int type;
  @Uint16() int virtualCode;
  @Uint16() int scanCode;
  @Uint64() int flags;
  @Uint64() int time;
  @Uint64() int dwExtraInfo;
  // Pointer dwExtraInfo;

  factory KeyboardInput.allocate(int virtualCode, int scanCode, int flags) =>
    allocate<KeyboardInput>().ref
      ..type = INPUT_KEYBOARD
      ..virtualCode = virtualCode
      ..scanCode = scanCode
      ..flags = flags
      ..time = 0
      ..dwExtraInfo = 0
      ;
}


class _MouseInput extends Struct {
  @Uint64()
  int dx;
  @Uint64()
  int dy;
  @Uint32()
  int mouseData;
  @Uint32()
  int flags;
  @Uint32()
  int time;
  Pointer extraInfo;
}



// ================================================================================
//
// Hotkeys
//
// ================================================================================

var hotkeys = <String, Function> {};

void _registerHookProc() {
  var callback = Pointer.fromFunction<winapi.KeyboardProc>(_keybdHookProc, 0);
  var hook = winapi.SetWindowsHookExW(winapi.WH_KEYBOARD_LL, callback, nullptr, 0);
  if (hook == nullptr) {
    // TODO: handle error
    print('couldnt register the hook');
  } else {
    print('Hook registered');
  }
}

int _keybdHookProc(int code, Pointer<Uint64> wParam, Pointer<Int64> lParam) {
  var event = wParam.address;
  Pointer<KBDLLHOOK> dataPtr = lParam.cast();
  var data = dataPtr.ref;

  var keyName = keyMap.entries.firstWhere((entry) => entry.value == data.vkCode, orElse: () => null);
  // TODO: encoding modifiers into string
  if (keyName != null && hotkeys.containsKey(keyName.key)) {
    if (event == winapi.WM_KEYDOWN) {
      hotkeys[keyName.key]();
    }
    return 1;
  } else {
    return winapi.CallNextHookEx(nullptr, code, wParam, lParam);
  }
}


class KBDLLHOOK extends Struct {
  @Uint32() int vkCode;
  @Uint32() int scanCode;
  @Uint32() int flags;
  @Uint32() int time;
  Pointer dwExtraInfo;
}


// ================================================================================
//
// Main Loop
//
// ================================================================================

void mainLoop() {
  _registerHookProc();

  var msg = allocate<MSG>();

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

class MSG extends Struct {
  Pointer hwnd;
  @Uint32() int message;
  Pointer<Uint64> wParam;
  Pointer<Int64> lParam;
  @Uint32() int time;
  @Int64() int pointX;
  @Int64() int pointY;
  @Uint64() int lPrivate;
}
