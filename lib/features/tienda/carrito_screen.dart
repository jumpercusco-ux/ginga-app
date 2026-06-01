import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/ginga_theme.dart';
import '../../core/services/tienda_service.dart';

class CarritoScreen extends StatefulWidget {
  const CarritoScreen({super.key});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  bool _isCheckingOut = false;
  bool _checkoutSuccess = false;
  String _pedidoCreadoId = '';
  double _pedidoTotal = 0.0;
  List<Map<String, dynamic>> _pedidoItems = [];

  Future<void> _enviarWhatsApp() async {
    // Texto estructurado del pedido
    String itemsText = '';
    for (var item in _pedidoItems) {
      final tallaStr = item['talla'] != null ? ' (Talla: ${item['talla']})' : '';
      itemsText += '• ${item['nombre']}$tallaStr x${item['cantidad']} - S/ ${(item['precio'] * item['cantidad']).toStringAsFixed(2)}\n';
    }

    final String message = 
        '🥋 *¡Hola Profesor! Acabo de reservar un pedido desde la App Ginga*\n\n'
        '📋 *Detalle del Pedido (${_pedidoCreadoId.substring(0, 6)}...):*\n'
        '$itemsText\n'
        '💰 *Total a pagar:* S/ ${_pedidoTotal.toStringAsFixed(2)}\n\n'
        'Coordinamos para realizar el pago en efectivo/yape y recoger mis artículos en la academia. ¡Muchas gracias! 👋';

    // Número de teléfono de prueba/academia (se puede configurar en Firestore o dejar como placeholder)
    const String telefonoProfesor = '51954642457'; // Número oficial de la academia
    final String url = 'https://wa.me/$telefonoProfesor?text=${Uri.encodeComponent(message)}';

    try {
      final Uri uri = Uri.parse(url);
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('WhatsApp lanzado correctamente');
      } else {
        throw 'No se pudo abrir el enlace de WhatsApp';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir WhatsApp automáticamente: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _realizarCheckout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isCheckingOut = true);

    try {
      // 1. Leer nombre del usuario desde Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final String userNombre = userDoc.exists ? (userDoc.data()?['nombre'] ?? 'Alumno') : 'Alumno';
      final String claseId = userDoc.exists ? (userDoc.data()?['clase_id'] ?? '') : '';

      final cartItems = TiendaService.instance.carrito.values.toList();
      final double total = TiendaService.instance.totalPrice;

      // Mapear items
      final List<Map<String, dynamic>> itemsMapeados = cartItems.map((item) => item.toMap()).toList();

      // 2. Registrar el pedido en Firestore
      final pedidoRef = await FirebaseFirestore.instance.collection('pedidos').add({
        'user_id': uid,
        'user_nombre': userNombre,
        'items': itemsMapeados,
        'total': total,
        'status': 'pendiente',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Generar notificación en el buzón del alumno
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notificaciones')
            .add({
          'titulo': 'Pedido registrado 🛍️',
          'mensaje': 'Tu pedido por un total de S/ ${total.toStringAsFixed(2)} ha sido reservado. Puedes recogerlo en tu academia oficial.',
          'fecha': FieldValue.serverTimestamp(),
          'leido': false,
          'tipo': 'tienda',
        });
      } catch (notiError) {
        debugPrint('Error al guardar notificación de pedido: $notiError');
      }

      // Generar notificación en el buzón del instructor
      try {
        String? instructorId;
        if (claseId.isNotEmpty) {
          final claseDoc = await FirebaseFirestore.instance.collection('clases').doc(claseId).get();
          if (claseDoc.exists) {
            instructorId = claseDoc.data()?['instructor_id'];
          }
        }
        instructorId ??= 'JGqDCSsPDBae4VLmtke9hKIYufh1'; // Fallback al instructor principal Luis Enrique

        if (instructorId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(instructorId)
              .collection('notificaciones')
              .add({
            'titulo': 'Nuevo pedido registrado 🛒',
            'mensaje': '$userNombre ha reservado productos por un total de S/ ${total.toStringAsFixed(2)} en la tienda.',
            'fecha': FieldValue.serverTimestamp(),
            'leido': false,
            'tipo': 'tienda',
          });
        }
      } catch (notiError) {
        debugPrint('Error al guardar notificación para el instructor: $notiError');
      }

      // 3. Guardar datos para WhatsApp
      _pedidoCreadoId = pedidoRef.id;
      _pedidoTotal = total;
      _pedidoItems = itemsMapeados;

      // 4. Vaciar carrito local
      TiendaService.instance.vaciarCarrito();

      setState(() {
        _isCheckingOut = false;
        _checkoutSuccess = true;
      });
    } catch (e) {
      setState(() => _isCheckingOut = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reservar el pedido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkoutSuccess) {
      return Scaffold(
        backgroundColor: GingaColors.backgroundLight,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: GingaColors.brandGreen,
                  size: 90,
                ),
                const SizedBox(height: 24),
                Text(
                  '¡Pedido Reservado! 🎉',
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: GingaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu solicitud ha sido guardada en nuestro sistema con estado Pendiente. Recuerda que no necesitas ingresar tarjetas; coordinarás la entrega y el pago en persona con tu profesor.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: GingaColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Botón Enviar WhatsApp
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _enviarWhatsApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // Color Verde WhatsApp
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.full),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    label: Text(
                      'Enviar Pedido por WhatsApp',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botón Volver al Catálogo
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () {
                      context.pop(); // Cierra el carrito y vuelve a la tienda
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: GingaColors.brandGreen, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GingaRadius.full),
                      ),
                    ),
                    child: Text(
                      'Volver al Catálogo',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: GingaColors.brandGreen,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: GingaColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: GingaColors.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: GingaColors.textPrimary),
          onPressed: () async {
            if (context.canPop()) {
              context.pop();
            } else {
              try {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  final doc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .get();
                  final role = doc.data()?['rol'] ?? 'alumno';
                  if (role == 'profesor') {
                    if (context.mounted) context.go('/instructor-clase');
                    return;
                  }
                }
              } catch (e) {
                debugPrint("Error al validar rol para navegacion back: $e");
              }
              if (context.mounted) context.go('/home');
            }
          },
        ),
        title: Text(
          'Carrito de Reservas',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: GingaColors.textPrimary,
          ),
        ),
      ),
      body: ValueListenableBuilder<Map<String, CartItem>>(
        valueListenable: TiendaService.instance.carritoNotifier,
        builder: (context, carrito, child) {
          if (carrito.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 70,
                    color: GingaColors.textSecondary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Tu carrito de reservas está vacío',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: GingaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Explora el catálogo y añade artículos',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: GingaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 180,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => context.pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GingaColors.brandGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GingaRadius.full),
                        ),
                      ),
                      child: Text(
                        'Explorar Tienda',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final keysList = carrito.keys.toList();
          final totalPrice = TiendaService.instance.totalPrice;

          return Column(
            children: [
              // ── Listado de Productos en el Carrito ──────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: keysList.length,
                  itemBuilder: (context, index) {
                    final key = keysList[index];
                    final item = carrito[key]!;

                    Color categoryColor = GingaColors.brandGreen;
                    IconData categoryIcon = Icons.shopping_bag_outlined;

                    if (item.categoria == 'instrumentos') {
                      categoryColor = GingaColors.accentAmber;
                      categoryIcon = Icons.music_note_outlined;
                    } else if (item.categoria == 'accesorios') {
                      categoryColor = Colors.purple;
                      categoryIcon = Icons.grade_outlined;
                    } else if (item.categoria == 'ropa') {
                      categoryIcon = Icons.checkroom_outlined;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(GingaRadius.lg),
                        border: Border.all(color: GingaColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          // Miniatura / Icono
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(GingaRadius.md),
                            ),
                            child: Icon(
                              categoryIcon,
                              color: categoryColor.withOpacity(0.6),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Información del artículo
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.nombre,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: GingaColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.talla != null) ...[
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: GingaColors.borderLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Talla: ${item.talla}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: GingaColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'S/ ${item.precio.toStringAsFixed(2)}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: GingaColors.brandGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Controles de cantidad / Eliminar
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () => TiendaService.instance.removerDelCarrito(key),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      TiendaService.instance.actualizarCantidad(key, item.cantidad - 1);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: GingaColors.borderLight),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.remove, size: 12),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      '${item.cantidad}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      TiendaService.instance.actualizarCantidad(key, item.cantidad + 1);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: GingaColors.borderLight),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add, size: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ── Panel Inferior del Checkout de Reservas ───────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: GingaColors.borderLight, width: 1.5),
                  ),
                ),
                child: Column(
                  children: [
                    // Desglose del total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Suma Total:',
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: GingaColors.textSecondary,
                          ),
                        ),
                        Text(
                          'S/ ${totalPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: GingaColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Comisión / Delivery:',
                          style: GoogleFonts.nunito(
                            fontSize: 12.5,
                            color: GingaColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Gratis (Recoger en Academia)',
                          style: GoogleFonts.nunito(
                            fontSize: 12.5,
                            color: GingaColors.brandGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Botón Confirmar Reserva
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isCheckingOut ? null : _realizarCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GingaColors.brandGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(GingaRadius.full),
                          ),
                        ),
                        child: _isCheckingOut
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'Reservar Pedido en Academia',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
