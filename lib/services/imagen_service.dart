import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Toma o elige una foto y la copia a la carpeta de la app; en la base de
/// datos solo se guarda la ruta.
class ImagenService {
  ImagenService._();
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> seleccionar(ImageSource origen) async {
    final x = await _picker.pickImage(source: origen, maxWidth: 900, imageQuality: 80);
    if (x == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final carpeta = Directory(p.join(dir.path, 'imagenes'));
    if (!await carpeta.exists()) await carpeta.create(recursive: true);
    final ext = p.extension(x.path).isEmpty ? '.jpg' : p.extension(x.path);
    final destino = p.join(carpeta.path, 'img_${DateTime.now().millisecondsSinceEpoch}$ext');
    await x.saveTo(destino);
    return destino;
  }

  static Future<void> eliminar(String? ruta) async {
    if (ruta == null || ruta.isEmpty) return;
    try {
      final f = File(ruta);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
