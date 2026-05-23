import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem {
  final String id;
  final String nombre;
  final double precio;
  final String imagenUrl;
  final String categoria;
  int cantidad;
  String? talla; // Solo para categoría 'ropa'

  CartItem({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.imagenUrl,
    required this.categoria,
    required this.cantidad,
    this.talla,
  });

  Map<String, dynamic> toMap() {
    return {
      'producto_id': id,
      'nombre': nombre,
      'precio': precio,
      'imagen_url': imagenUrl,
      'categoria': categoria,
      'cantidad': cantidad,
      'talla': talla,
    };
  }
}

class TiendaService {
  TiendaService._();
  static final TiendaService instance = TiendaService._();

  // Estado reactivo del carrito en memoria: Clave es "productoId_talla" para separar abadás de diferente talla
  final ValueNotifier<Map<String, CartItem>> carritoNotifier = ValueNotifier<Map<String, CartItem>>({});

  Map<String, CartItem> get carrito => carritoNotifier.value;

  int get totalItemsCount {
    int total = 0;
    carrito.forEach((key, item) {
      total += item.cantidad;
    });
    return total;
  }

  double get totalPrice {
    double total = 0.0;
    carrito.forEach((key, item) {
      total += (item.precio * item.cantidad);
    });
    return total;
  }

  /// Agrega un producto al carrito
  void agregarAlCarrito({
    required String id,
    required String nombre,
    required double precio,
    required String imagenUrl,
    required String categoria,
    int cantidad = 1,
    String? talla,
  }) {
    final key = talla != null ? '${id}_$talla' : id;
    final nuevoCarrito = Map<String, CartItem>.from(carritoNotifier.value);

    if (nuevoCarrito.containsKey(key)) {
      nuevoCarrito[key]!.cantidad += cantidad;
    } else {
      nuevoCarrito[key] = CartItem(
        id: id,
        nombre: nombre,
        precio: precio,
        imagenUrl: imagenUrl,
        categoria: categoria,
        cantidad: cantidad,
        talla: talla,
      );
    }
    
    carritoNotifier.value = nuevoCarrito;
  }

  /// Remueve un artículo específico del carrito
  void removerDelCarrito(String key) {
    final nuevoCarrito = Map<String, CartItem>.from(carritoNotifier.value);
    nuevoCarrito.remove(key);
    carritoNotifier.value = nuevoCarrito;
  }

  /// Actualiza la cantidad de un artículo
  void actualizarCantidad(String key, int nuevaCantidad) {
    if (nuevaCantidad <= 0) {
      removerDelCarrito(key);
      return;
    }
    final nuevoCarrito = Map<String, CartItem>.from(carritoNotifier.value);
    if (nuevoCarrito.containsKey(key)) {
      nuevoCarrito[key]!.cantidad = nuevaCantidad;
      carritoNotifier.value = nuevoCarrito;
    }
  }

  /// Vacía por completo el carrito
  void vaciarCarrito() {
    carritoNotifier.value = {};
  }

  /// Carga datos mockup a Firestore de forma automática si la colección /productos está vacía
  Future<void> inicializarProductosMockupSiVacia() async {
    try {
      final query = await FirebaseFirestore.instance.collection('productos').limit(1).get();
      if (query.docs.isEmpty) {
        debugPrint('Inicializando colección /productos con productos de prueba...');
        final batch = FirebaseFirestore.instance.batch();

        final mockProducts = [
          {
            'nombre': 'Abadá Oficial Ginga',
            'descripcion': 'El abadá oficial de nuestra academia. Confeccionado en tejido helanca elástico de alta resistencia, costuras reforzadas para soportar acrobacias, patadas y movimientos rápidos. Incluye pasadores para la corda y bordado prémium de Ginga Capoeira en la pierna izquierda.',
            'precio': 85.00,
            'categoria': 'ropa',
            'imagen_url': 'assets/images/placeholder_abada.jpg',
            'stock': 15,
            'rating': 4.9,
          },
          {
            'nombre': 'Camiseta Oficial de Entrenamiento',
            'descripcion': 'Polera de algodón peinado 100% peruano de tacto ultrasuave. Color blanco con el imagotipo oficial impreso en verde Ginga en el pecho y espalda. Ideal para tus clases regulares y seminarios intensivos.',
            'precio': 45.00,
            'categoria': 'ropa',
            'imagen_url': 'assets/images/placeholder_tshirt.jpg',
            'stock': 30,
            'rating': 4.7,
          },
          {
            'nombre': 'Berimbau Profesional Completo',
            'descripcion': 'Instrumento tradicional tallado a mano con madera de biriba seleccionada de la mejor elasticidad y afinación. El kit incluye: una verga de madera curada, una cabaza barnizada afinada, un caxixi de fibra natural, una baqueta de tucum y un dobrão de piedra natural.',
            'precio': 260.00,
            'categoria': 'instrumentos',
            'imagen_url': 'assets/images/placeholder_berimbau.jpg',
            'stock': 5,
            'rating': 5.0,
          },
          {
            'nombre': 'Pandeiro de Madera (10 pulgadas)',
            'descripcion': 'Pandeiro profesional ultraligero y de excelente sonoridad. Aro de madera noble de 10 pulgadas con parches de cuero de cabra natural afinables. Herrajes cromados de alta precisión para regular el tono. Sonido limpio e ideal para las rodas.',
            'precio': 140.00,
            'categoria': 'instrumentos',
            'imagen_url': 'assets/images/placeholder_pandeiro.jpg',
            'stock': 8,
            'rating': 4.8,
          },
          {
            'nombre': 'Polera Ginga Hoodie Premium',
            'descripcion': 'Casaca con capucha y bolsillo canguro hecha con franela de algodón abrigadora. Logo estampado en contraste, puños y cintura acanalados. Perfecta para no enfriarte durante el calentamiento previo a la roda.',
            'precio': 120.00,
            'categoria': 'ropa',
            'imagen_url': 'assets/images/placeholder_hoodie.jpg',
            'stock': 12,
            'rating': 4.6,
          },
          {
            'nombre': 'Llavero Berimbau de Madera',
            'descripcion': 'Llavero miniatura tallado y pintado a mano que representa al berimbau. Un accesorio súper capoeirista para tus llaves, mochila o bolso de entrenamiento.',
            'precio': 15.00,
            'categoria': 'accesorios',
            'imagen_url': 'assets/images/placeholder_llavero.jpg',
            'stock': 50,
            'rating': 4.5,
          }
        ];

        for (var prod in mockProducts) {
          final docRef = FirebaseFirestore.instance.collection('productos').doc();
          batch.set(docRef, prod);
        }

        await batch.commit();
        debugPrint('Se crearon 6 productos de prueba con éxito.');
      }
    } catch (e) {
      debugPrint('Error al inicializar productos mockup: $e');
    }
  }
}
