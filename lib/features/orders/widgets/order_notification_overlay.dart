import 'dart:async';
import 'package:flutter/material.dart';

class OrderNotification {
  final String id;
  final String title;
  final String subtitle;
  final String paymentMethod;
  final String customerName;
  final double? totalPrice;
  final DateTime arrivedAt;

  OrderNotification({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.paymentMethod,
    required this.customerName,
    this.totalPrice,
  }) : arrivedAt = DateTime.now();

  bool get isQris =>
      ['qris', 'midtrans', 'gopay', 'other_qris']
          .contains(paymentMethod.toLowerCase().trim());

  bool get isCash =>
      paymentMethod.toLowerCase() == 'cash' ||
      paymentMethod.toLowerCase() == 'tunai' ||
      paymentMethod.trim().isEmpty;

  Color get accentColor {
    if (isQris) return const Color(0xFFE53935);
    if (isCash) return const Color(0xFFF57C00);
    return const Color(0xFF1565C0);
  }

  IconData get icon {
    if (isQris) return Icons.qr_code_2_rounded;
    if (isCash) return Icons.payments_rounded;
    return Icons.credit_card_rounded;
  }

  String get methodLabel {
    if (isQris) return 'QRIS';
    if (isCash) return 'TUNAI';
    return paymentMethod.toUpperCase();
  }
}

// ── Singleton controller ──────────────────────────────────────
class OrderNotificationController {
  static final OrderNotificationController _instance =
      OrderNotificationController._internal();
  factory OrderNotificationController() => _instance;
  OrderNotificationController._internal();

  final StreamController<OrderNotification> _stream =
      StreamController<OrderNotification>.broadcast();

  Stream<OrderNotification> get stream => _stream.stream;

  void show(OrderNotification notification) {
// debugPrint('🔔 [NOTIF SENT] ${notification.title} — ${notification.customerName}');
    _stream.add(notification);
  }

  void dispose() => _stream.close();
}

// ── Layer — pasang satu kali, bungkus seluruh Scaffold ───────
class OrderNotificationLayer extends StatefulWidget {
  final Widget child;
  const OrderNotificationLayer({super.key, required this.child});

  @override
  State<OrderNotificationLayer> createState() => _OrderNotificationLayerState();
}

class _OrderNotificationLayerState extends State<OrderNotificationLayer> {
  final List<_ActiveNotif> _active = [];
  StreamSubscription<OrderNotification>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = OrderNotificationController().stream.listen(_onNew);
// debugPrint('✅ [OrderNotificationLayer] stream listener terpasang');
  }

  void _onNew(OrderNotification notif) {
// debugPrint('🎯 [OrderNotificationLayer] notif diterima: ${notif.title}');
    if (!mounted) return;
    setState(() => _active.add(_ActiveNotif(notif: notif, key: UniqueKey())));
  }

  void _dismiss(Key key) {
    if (!mounted) return;
    setState(() => _active.removeWhere((n) => n.key == key));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // ✅ PERUBAHAN: tengah atas, muncul dari atas ke bawah
        Positioned(
          top: 95,   // tepat di bawah TopBar (85px) + sedikit margin
          left: 0,
          right: 0,
          child: Center(
            child: Stack(
              alignment: Alignment.topCenter,
              children: _active
                  .map((a) => _NotifCard(
                        key: a.key,
                        notif: a.notif,
                        onDismiss: () => _dismiss(a.key),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveNotif {
  final OrderNotification notif;
  final Key key;
  _ActiveNotif({required this.notif, required this.key});
}

// ── Kartu notifikasi individual ───────────────────────────────
class _NotifCard extends StatefulWidget {
  final OrderNotification notif;
  final VoidCallback onDismiss;
  const _NotifCard({super.key, required this.notif, required this.onDismiss});

  @override
  State<_NotifCard> createState() => _NotifCardState();
}

class _NotifCardState extends State<_NotifCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  Timer? _dismiss;
  Timer? _countdown;
  int _rem = 12;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // ✅ PERUBAHAN: slide dari atas (Y negatif) bukan dari kanan
    _slide = Tween<Offset>(begin: const Offset(0, -1.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.5)));

    _ctrl.forward();

    // Pulse dihapus (disembunyikan) sesuai request

    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _rem--);
      if (_rem <= 0) _doDismiss();
    });

    _dismiss = Timer(const Duration(seconds: 12), _doDismiss);
  }

  void _doDismiss() {
    _dismiss?.cancel();
    _countdown?.cancel();
    if (!mounted) return;
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _dismiss?.cancel();
    _countdown?.cancel();
    super.dispose();
  }

  String _fmtRp(double v) {
    final s = v.toInt().toString();
    final buf = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write('.');
      buf.write(s[i]);
      c++;
    }
    return 'Rp ${buf.toString().split('').reversed.join('')}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.notif.accentColor;
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          width: 320,
          margin: const EdgeInsets.only(bottom: 10),
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(18),
            shadowColor: accent.withValues(alpha: 0.3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: accent.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.08),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(17)),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(widget.notif.icon,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.notif.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                widget.notif.methodLabel,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 10,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _doDismiss,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: accent.withValues(alpha: 0.1),
                              child: Text(
                                widget.notif.customerName.isNotEmpty
                                    ? widget.notif.customerName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.notif.customerName.isNotEmpty
                                        ? widget.notif.customerName
                                        : 'Pesanan Baru',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  Text(
                                    widget.notif.subtitle,
                                    style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 11,
                                        fontFamily: 'Poppins'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (widget.notif.totalPrice != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total',
                                    style: TextStyle(
                                        color: Colors.black54, fontSize: 11)),
                                Text(
                                  _fmtRp(widget.notif.totalPrice!),
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _rem / 12,
                            minHeight: 3,
                            backgroundColor: accent.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('Tutup dalam ${_rem}s',
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.black38)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}