import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Pre-initializes mpv environment configuration before MediaKit boots up.
///
/// On Linux desktop, libmpv defaults to spawning internal Lua scripts (like stats.lua)
/// using LuaJIT 2.1. LuaJIT invokes `_Unwind_RaiseException` during exceptions / seeks,
/// which collides with Flutter engine's exported unwinder symbol and causes SIGSEGV.
/// Writing a dedicated mpv.conf and setting MPV_HOME eliminates all Lua threads.
class MpvConfig {
  static void configure() {
    if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) return;

    try {
      final dir = Directory('${Directory.systemTemp.path}/ani_mobile_mpv');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final conf = File('${dir.path}/mpv.conf');
      conf.writeAsStringSync('''
load-scripts=no
load-stats-overlay=no
load-console=no
load-commands=no
load-context-menu=no
load-positioning=no
load-select=no
osc=no
ytdl=no
''');

      if (Platform.isLinux || Platform.isMacOS) {
        final libc = DynamicLibrary.process();
        final setenv = libc.lookupFunction<
            Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32),
            int Function(Pointer<Utf8>, Pointer<Utf8>, int)>('setenv');
        final k = 'MPV_HOME'.toNativeUtf8();
        final v = dir.path.toNativeUtf8();
        setenv(k, v, 1);
        calloc.free(k);
        calloc.free(v);
      }
    } catch (e) {
      print('MpvConfig configure error: $e');
    }
  }
}
