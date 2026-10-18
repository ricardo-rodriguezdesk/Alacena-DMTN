// Ejecutar UNA vez después de `flutter create .`:
//
//   dart run tool/configurar_plataformas.dart
//
// Agrega lo que necesitan flutter_local_notifications e image_picker:
//  - Android: desugaring en build.gradle(.kts), permisos y receivers en el
//    AndroidManifest para las alarmas programadas.
//  - iOS: textos de permiso de cámara/galería en Info.plist.
import 'dart:io';

void main() {
  _gradle();
  _manifest();
  _infoPlist();
  stdout.writeln('\n✅ Listo. Ahora ejecuta: flutter pub get && flutter run');
}

void _gradle() {
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  if (kts.existsSync()) {
    var s = kts.readAsStringSync();
    if (!s.contains('isCoreLibraryDesugaringEnabled')) {
      final re = RegExp(r'compileOptions\s*\{');
      if (!re.hasMatch(s)) {
        stderr.writeln('⚠️  No encontré "compileOptions {" en build.gradle.kts; agrégalo a mano (ver README).');
      } else {
        s = s.replaceFirst(re, 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true');
      }
    }
    if (!s.contains('desugar_jdk_libs')) {
      s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n';
    }
    kts.writeAsStringSync(s);
    stdout.writeln('✔ android/app/build.gradle.kts');
  } else if (groovy.existsSync()) {
    var s = groovy.readAsStringSync();
    if (!s.contains('coreLibraryDesugaringEnabled')) {
      final re = RegExp(r'compileOptions\s*\{');
      if (!re.hasMatch(s)) {
        stderr.writeln('⚠️  No encontré "compileOptions {" en build.gradle; agrégalo a mano (ver README).');
      } else {
        s = s.replaceFirst(re, 'compileOptions {\n        coreLibraryDesugaringEnabled true');
      }
    }
    if (!s.contains('desugar_jdk_libs')) {
      s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n";
    }
    groovy.writeAsStringSync(s);
    stdout.writeln('✔ android/app/build.gradle');
  } else {
    stderr.writeln('⚠️  No existe la carpeta android. Ejecuta primero: flutter create --org com.alacena --project-name alacena --platforms=android,ios .');
  }
}

void _manifest() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) return;
  var s = f.readAsStringSync();
  if (!s.contains('POST_NOTIFICATIONS')) {
    const permisos = '''    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
''';
    // Se insertan justo después de la etiqueta de apertura <manifest ...>.
    final inicio = s.indexOf('<manifest');
    final fin = s.indexOf('>', inicio) + 1;
    s = '${s.substring(0, fin)}\n$permisos${s.substring(fin)}';
  }
  if (!s.contains('ScheduledNotificationReceiver')) {
    const receivers = '''        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
''';
    // Se insertan al inicio de la línea que contiene </application>.
    final cierre = s.lastIndexOf('</application>');
    final linea = s.lastIndexOf('\n', cierre) + 1;
    s = s.substring(0, linea) + receivers + s.substring(linea);
  }
  f.writeAsStringSync(s);
  stdout.writeln('✔ AndroidManifest.xml');
}

void _infoPlist() {
  final f = File('ios/Runner/Info.plist');
  if (!f.existsSync()) return;
  var s = f.readAsStringSync();
  if (s.contains('NSCameraUsageDescription')) return;
  const claves = '''	<key>NSCameraUsageDescription</key>
	<string>Para tomar la foto de tus artículos.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Para elegir la foto de tus artículos.</string>
''';
  final i = s.lastIndexOf('</dict>');
  s = s.substring(0, i) + claves + s.substring(i);
  f.writeAsStringSync(s);
  stdout.writeln('✔ ios/Runner/Info.plist');
}
