
import 'package:robotize/robotize.dart';

main() {
  // print('Current window:');
  // var id = getActiveWindow();
  // print(id.asPointer().address);
  // print(getWindowText(id));
  // print(getWindowInfo(id));
  var active = Windows.getActiveWindow();
  print(active.getWindowText());

  // print('All windows:');
  // var windows = listWindows();
  // print('Found ${windows.length} windows!');
  var windows = Windows.list();
  for(var window in windows) {
    print(window.getWindowText());
  }

  // print('Switch to "YakYak"');
  // var window = findWindow(WindowQuery(titleMatcher: "YakYak"));
  // // activateWindow(window.id);

  // var viewer = findWindow(WindowQuery(titleMatcher: "DLL Export Viewer"));
  // activateWindow(viewer.id);
  // print(quitWindow(viewer.id));

  // var notepad = findWindow(WindowQuery(titleMatcher: "WindowsProject1"));
  // var notepad = findWindow(WindowQuery(titleMatcher: "Firefox"));
  // var notepad = findWindow(WindowQuery(titleMatcher: "Notatnik"));
  // activateWindow(notepad.id);
  // sleep(Duration(milliseconds: 1000));
  // sendKey(notepad.id, "hello".codeUnitAt(0));

  // var notepad = findWindow(WindowQuery(titleMatcher: "Notepad"));
  // print('Activating window');
  // activateWindow(notepad.id);
  // print('Writing...');
  // sleep(Duration(milliseconds: 500));

  // sendInput("Hello World!");
  // quitWindow(notepad.id);

  Hotkey.add("F2", () {
    Input.send("Hello world");
  });

  Robotize.start();
}
