import 'package:flutter/material.dart';

class TeenInfoCardData {
  const TeenInfoCardData({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    this.imagePath,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final String? imagePath;
}

class TeenInfoCarousel extends StatefulWidget {
  const TeenInfoCarousel({
    super.key,
    required this.cards,
    this.height = 390,
  });

  final List<TeenInfoCardData> cards;
  final double height;

  @override
  State<TeenInfoCarousel> createState() => _TeenInfoCarouselState();
}

class _TeenInfoCarouselState extends State<TeenInfoCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.9);
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.cards.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final card = widget.cards[index];
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  var page = _currentPage.toDouble();
                  if (_controller.hasClients && _controller.page != null) {
                    page = _controller.page!;
                  }
                  final distance = (page - index).abs().clamp(0.0, 1.0);
                  final scale = 1 - (distance * 0.06);
                  final opacity = 1 - (distance * 0.18);
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                        margin: EdgeInsets.fromLTRB(
                          index == 0 ? 0 : 8,
                          index == _currentPage ? 0 : 10,
                          8,
                          index == _currentPage ? 10 : 20,
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
                child: _TeenInfoCard(
                  card: card,
                  pageLabel: '${index + 1}/${widget.cards.length}',
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.cards.length, (index) {
            final isActive = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: isActive ? 22 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? widget.cards[_currentPage].color
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _TeenInfoCard extends StatelessWidget {
  const _TeenInfoCard({
    required this.card,
    required this.pageLabel,
  });

  final TeenInfoCardData card;
  final String pageLabel;

  void _showExpandedImage(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: SafeArea(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.asset(
                          card.imagePath!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: card.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cerrar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: card.color.withValues(alpha: 0.22),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              card.color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: card.color.withValues(alpha: 0.09),
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
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.92, end: 1),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: card.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        card.icon,
                        color: card.color,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      card.title,
                      style: TextStyle(
                        color: card.color.withValues(alpha: 0.95),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      pageLabel,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (card.imagePath != null) ...[
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _showExpandedImage(context),
                      child: Image.asset(
                        card.imagePath!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      card.body,
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
            ],
          ),
        ),
      ),
    );
  }
}
