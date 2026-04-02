import 'package:flutter/material.dart';

// =====================================
// WIDGET BANTUAN: EFEK HOVER ANIMASI
// =====================================
class HoverScale extends StatefulWidget {
  final Widget child;
  
  const HoverScale({super.key, required this.child});

  @override
  State<HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<HoverScale> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click, 
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0, 
        duration: const Duration(milliseconds: 200), 
        curve: Curves.easeInOut, 
        child: widget.child,
      ),
    );
  }
}