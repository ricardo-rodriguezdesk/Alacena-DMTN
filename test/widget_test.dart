import 'package:alacena/models/estatus.dart';
import 'package:alacena/models/producto.dart';
import 'package:alacena/utils/fechas.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas de las reglas de estatus (no requieren base de datos).
void main() {
  Producto prod({int stock = 5, int minimo = 1, int aviso = 3, String? caduca}) => Producto(
        id: 1,
        nombre: 'Prueba',
        categoriaId: 1,
        stock: stock,
        stockMinimo: minimo,
        diasAviso: aviso,
        proximaCaducidad: caduca,
      );

  test('Sin lotes o stock 0 => Agotado', () {
    expect(prod(stock: 0).estatus, contains(Estatus.agotado));
  });

  test('Stock menor o igual al mínimo => Por agotarse', () {
    expect(prod(stock: 2, minimo: 2).estatusPrincipal, Estatus.porAgotarse);
  });

  test('Caducidad pasada => Caducado (más grave)', () {
    expect(prod(stock: 1, minimo: 1, caduca: Fechas.masDias(-1)).estatusPrincipal, Estatus.caducado);
  });

  test('Caduca dentro de los días de aviso => Por caducar', () {
    expect(prod(caduca: Fechas.masDias(2), aviso: 3).estatusPrincipal, Estatus.porCaducar);
  });

  test('Todo bien => En orden', () {
    expect(prod(caduca: Fechas.masDias(30)).estatusPrincipal, Estatus.ok);
  });
}
