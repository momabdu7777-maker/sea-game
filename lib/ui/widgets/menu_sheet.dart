import 'package:flutter/material.dart';

import '../theme.dart';

/// لوحة قائمة تنزلق من الأسفل فوق اللعبة (الشرح، التطوير، المراحل).
class MenuSheet extends StatefulWidget {
  const MenuSheet({super.key, required this.title, required this.onClose, required this.child, this.header, this.footer});

  final String title;
  final VoidCallback onClose;

  /// سطر تحت العنوان (مثل الرصيد).
  final Widget? header;

  /// محتوى قابل للتمرير.
  final Widget child;

  /// زر ثابت في الأسفل.
  final Widget? footer;

  @override
  State<MenuSheet> createState() => _MenuSheetState();
}

class _MenuSheetState extends State<MenuSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..forward();
  bool _closing = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await _c.animateBack(0, duration: const Duration(milliseconds: 200), curve: Curves.easeIn);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.9;
    return Stack(
      children: [
        GestureDetector(
          onTap: _close,
          child: FadeTransition(
            opacity: _c,
            child: const ColoredBox(color: Color(0x99021428), child: SizedBox.expand()),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic)),
            child: Container(
              constraints: BoxConstraints(maxHeight: maxH, maxWidth: 560),
              decoration: const BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 24)],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 8, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.seaDeep),
                              ),
                            ),
                            IconButton(
                              onPressed: _close,
                              tooltip: 'إغلاق',
                              icon: const Icon(Icons.close_rounded, size: 30, color: AppColors.seaDeep),
                            ),
                          ],
                        ),
                      ),
                      if (widget.header != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: widget.header),
                      Flexible(
                        child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 12), child: widget.child),
                      ),
                      if (widget.footer != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: widget.footer),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// زر برتقالي كبير (نفس زر «رمية جديدة»).
class BigButton extends StatefulWidget {
  const BigButton({super.key, required this.label, required this.onTap, this.height = 64, this.fontSize = 24});

  final String label;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;

  @override
  State<BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<BigButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final top = enabled ? AppColors.coral : const Color(0xFFB0BEC5);
    final bottom = enabled ? AppColors.coralDark : const Color(0xFF90A4AE);
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          height: widget.height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [top, bottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(widget.height * 0.34),
            boxShadow: [BoxShadow(color: bottom.withValues(alpha: 0.5), offset: Offset(0, _down ? 2 : 6), blurRadius: 0)],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.label,
              style: TextStyle(fontSize: widget.fontSize, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// شريط تقدم صغير بزوايا دائرية.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color = const Color(0xFF2E9D57), this.height = 8});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: Stack(
      children: [
        Container(height: height, color: const Color(0x1F062B4F)),
        FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(height: height, color: color),
        ),
      ],
    ),
  );
}
