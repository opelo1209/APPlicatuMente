import 'package:flutter/material.dart';

class ParentTriptychPanel {
  const ParentTriptychPanel({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String body;
  final IconData icon;
  final Color color;
}

class ParentTriptych extends StatefulWidget {
  const ParentTriptych({
    super.key,
    required this.panels,
    this.height = 500,
  });

  final List<ParentTriptychPanel> panels;
  final double height;

  @override
  State<ParentTriptych> createState() => _ParentTriptychState();
}

class _ParentTriptychState extends State<ParentTriptych> {
  late final PageController _controller;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectPanel(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _moveBy(int delta) {
    final next = (_selectedIndex + delta).clamp(
      0,
      widget.panels.length - 1,
    ) as int;
    _selectPanel(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(widget.panels.length, (index) {
            final panel = widget.panels[index];
            final isSelected = index == _selectedIndex;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 4,
                  right: index == widget.panels.length - 1 ? 0 : 4,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _selectPanel(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    height: 86,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? panel.color.withValues(alpha: 0.14)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? panel.color.withValues(alpha: 0.48)
                            : const Color(0xFFE5E7EB),
                        width: 1.4,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: panel.color.withValues(alpha: 0.12),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          panel.icon,
                          color: isSelected
                              ? panel.color
                              : const Color(0xFF6B7280),
                          size: 24,
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          width: isSelected ? 28 : 12,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? panel.color
                                : const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            panel.title,
                            maxLines: 1,
                            style: TextStyle(
                              color: isSelected
                                  ? panel.color.withValues(alpha: 0.95)
                                  : const Color(0xFF374151),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.panels.length,
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final panel = widget.panels[index];
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offsetAnimation = Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: offsetAnimation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.98, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
                child: _TriptychPanelCard(
                  key: ValueKey(panel.title),
                  panel: panel,
                  pageLabel: 'Panel ${index + 1} de ${widget.panels.length}',
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _TriptychNavButton(
              icon: Icons.chevron_left_rounded,
              enabled: _selectedIndex > 0,
              onTap: () => _moveBy(-1),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (_selectedIndex + 1) / widget.panels.length,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.panels[_selectedIndex].color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _TriptychNavButton(
              icon: Icons.chevron_right_rounded,
              enabled: _selectedIndex < widget.panels.length - 1,
              onTap: () => _moveBy(1),
            ),
          ],
        ),
      ],
    );
  }
}

class _TriptychNavButton extends StatelessWidget {
  const _TriptychNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.35,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF374151), size: 26),
        ),
      ),
    );
  }
}

class _TriptychPanelCard extends StatelessWidget {
  const _TriptychPanelCard({
    super.key,
    required this.panel,
    required this.pageLabel,
  });

  final ParentTriptychPanel panel;
  final String pageLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: panel.color.withValues(alpha: 0.24)),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            panel.color.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: panel.color.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: panel.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(panel.icon, color: panel.color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pageLabel,
                        style: TextStyle(
                          color: panel.color.withValues(alpha: 0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        panel.subtitle,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 21,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  panel.body,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 15,
                    height: 1.48,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
