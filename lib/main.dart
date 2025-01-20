import 'dart:ui';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Dock(
            items: const [
              Icons.person,
              Icons.message,
              Icons.call,
              Icons.camera,
              Icons.photo,
            ],
            builder: (e) {
              return Container(
                constraints: const BoxConstraints(minWidth: 48),
                height: 48,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.primaries[e.hashCode % Colors.primaries.length],
                ),
                child: Center(child: Icon(e, color: Colors.white)),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Dock of the reorderable [items].
class Dock<T extends Object> extends StatefulWidget {
  const Dock({
    super.key,
    this.items = const [],
    required this.builder,
  });

  /// Initial [T] items to put in this [Dock].
  final List<T> items;

  /// Builder building the provided [T] item.
  final Widget Function(T) builder;

  @override
  State<Dock<T>> createState() => _DockState<T>();
}

/// Handles animation calculations for a single dock item
class DockItemAnimation {
  const DockItemAnimation({
    this.baseScale = 1.0,
    this.maxScale = 1.3,
    this.neighborScale = 1.1,
    this.baseTranslationY = 0.0,
    this.maxTranslationY = -10.0,
    this.neighborTranslationY = -6.0,
    this.affectedItemsCount = 2,
  });

  final double baseScale;
  final double maxScale;
  final double neighborScale;
  final double baseTranslationY;
  final double maxTranslationY;
  final double neighborTranslationY;
  final int affectedItemsCount;

  double _calculateProperty({
    required int itemIndex,
    required int? hoveredIndex,
    required double baseValue,
    required double maxValue,
    required double neighborValue,
  }) {
    if (hoveredIndex == null) return baseValue;

    final distance = (hoveredIndex - itemIndex).abs();
    if (distance == 0) return maxValue;

    if (distance <= affectedItemsCount) {
      final ratio = (affectedItemsCount - distance) / affectedItemsCount;
      return lerpDouble(baseValue, neighborValue, ratio)!;
    }

    return baseValue;
  }

  double getScale(int itemIndex, int? hoveredIndex) {
    return _calculateProperty(
      itemIndex: itemIndex,
      hoveredIndex: hoveredIndex,
      baseValue: baseScale,
      maxValue: maxScale,
      neighborValue: neighborScale,
    );
  }

  double getTranslationY(int itemIndex, int? hoveredIndex) {
    return _calculateProperty(
      itemIndex: itemIndex,
      hoveredIndex: hoveredIndex,
      baseValue: baseTranslationY,
      maxValue: maxTranslationY,
      neighborValue: neighborTranslationY,
    );
  }

  Matrix4 getTransform(int itemIndex, int? hoveredIndex) {
    return Matrix4.identity()
      ..scale(getScale(itemIndex, hoveredIndex))
      ..translate(0, getTranslationY(itemIndex, hoveredIndex));
  }
}

class ReturnPathPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final double progress;
  final Paint pathPaint;

  ReturnPathPainter({
    required this.start,
    required this.end,
    required this.progress,
  }) : pathPaint = Paint()
          ..color = Colors.blue.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    // Tworzymy krzywą Beziera dla płynniejszej animacji
    final controlPoint1 = Offset(start.dx, start.dy + (end.dy - start.dy) / 2);
    final controlPoint2 = Offset(end.dx, start.dy + (end.dy - start.dy) / 2);
    
    path.moveTo(start.dx, start.dy);
    path.cubicTo(
      controlPoint1.dx, controlPoint1.dy,
      controlPoint2.dx, controlPoint2.dy,
      end.dx, end.dy,
    );

    final pathMetric = path.computeMetrics().first;
    final extractPath = pathMetric.extractPath(
      0.0,
      pathMetric.length * progress,
    );

    canvas.drawPath(extractPath, pathPaint);
  }

  @override
  bool shouldRepaint(ReturnPathPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// State of the [Dock] used to manipulate the [_items].
class _DockState<T extends Object> extends State<Dock<T>> with TickerProviderStateMixin {
  /// [T] items being manipulated.
  late final List<T> _items = widget.items.toList();
  int? _hoveredIndex;
  int? _draggedIndex;
  Offset? _dragStartPosition;
  Offset? _dragEndPosition;
  Offset? _itemOriginalPosition;
  AnimationController? _returnAnimationController;
  Widget? _returningWidget;
  T? _draggedItem;  // Dodajemy zmienną do przechowywania przeciąganego elementu
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  // Tworzymy jedną instancję dla wszystkich elementów
  final _animation = const DockItemAnimation();
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _items.length; i++) {
      _itemKeys[i] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _returnAnimationController?.dispose();
    super.dispose();
  }

  void _handleReorder(int oldIndex, int newIndex) {
    final item = _items[oldIndex];
    setState(() {
      _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  void _handleRemoveItem(int index) {
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => const SizedBox.shrink(),
      duration: const Duration(milliseconds: 1),
    );
    
    setState(() {
      _items.removeAt(index);
    });
  }

  Offset _getItemPosition(int index) {
    final RenderBox? renderBox = _itemKeys[index]?.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    
    if (renderBox == null || overlay == null) return Offset.zero;
    
    return renderBox.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
  }

  void _startReturnAnimation(Offset dragEndPosition, int itemIndex) {
    if (_draggedItem == null) return;  // Zabezpieczenie
    
    _dragEndPosition = dragEndPosition;
    _itemOriginalPosition = _dragStartPosition;
    _returningWidget = Material(
      color: Colors.transparent,
      child: widget.builder(_draggedItem!),
    );
    
    _returnAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    final curvedAnimation = CurvedAnimation(
      parent: _returnAnimationController!,
      curve: Curves.easeOutExpo,
    );

    curvedAnimation.addListener(() {
      setState(() {});
    });

    _returnAnimationController!.forward().then((_) {
      setState(() {
        _dragStartPosition = null;
        _dragEndPosition = null;
        _itemOriginalPosition = null;
        _returningWidget = null;
        // Dodajemy zapisany element z powrotem do listy
        _items.insert(itemIndex, _draggedItem!);
        _listKey.currentState?.insertItem(
          itemIndex, 
          duration: const Duration(milliseconds: 150),
        );
        _draggedItem = null;  // Czyścimy zapisany element
      });
      _returnAnimationController!.dispose();
      _returnAnimationController = null;
    });
  }

  Widget _buildItem(BuildContext context, int index, Animation<double> animation) {
    // Tworzymy złożoną animację, która będzie szybsza i bardziej dynamiczna
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutExpo,
    );

    return SizeTransition(
      axis: Axis.horizontal,
      sizeFactor: curvedAnimation,
      child: FadeTransition(
        opacity: curvedAnimation,
        child: DragTarget<int>(
          onWillAcceptWithDetails: (details) {
            final draggedIndex = details.data;
            return draggedIndex != index;
          },
          onAcceptWithDetails: (details) {
            final draggedIndex = details.data;
            _handleReorder(draggedIndex, index);
          },
          builder: (context, candidateData, rejectedData) {
            return Draggable<int>(
              data: index,
              feedback: Material(
                color: Colors.transparent,
                child: widget.builder(_items[index]),
              ),
              childWhenDragging: const SizedBox.shrink(),
              onDragStarted: () {
                _dragStartPosition = _getItemPosition(index);
                _draggedItem = _items[index];  // Zapisujemy element przed rozpoczęciem przeciągania
                setState(() => _draggedIndex = index);
              },
              onDraggableCanceled: (velocity, offset) {
                _handleRemoveItem(index);
                _startReturnAnimation(offset, index);
                setState(() => _draggedIndex = null);
              },
              onDragEnd: (_) => setState(() => _draggedIndex = null),
              child: KeyedSubtree(
                key: _itemKeys[index],
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hoveredIndex = index),
                  onExit: (_) => setState(() => _hoveredIndex = null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutExpo,
                    transformAlignment: Alignment.center,
                    transform: _draggedIndex == index 
                      ? Matrix4.identity()
                      : _animation.getTransform(index, _hoveredIndex),
                    child: widget.builder(_items[index]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black12,
            ),
            padding: const EdgeInsets.all(4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 64),  // wysokość ikony (48) + padding (8+8)
              child: AnimatedList(
                key: _listKey,
                initialItemCount: _items.length,
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: _buildItem,
              ),
            ),
          ),
        ),
        if (_dragEndPosition != null && _itemOriginalPosition != null && _returnAnimationController != null && _returningWidget != null)
          Positioned.fill(
            child: Stack(
              children: [
                Positioned(
                  left: lerpDouble(_dragEndPosition!.dx, _itemOriginalPosition!.dx, _returnAnimationController!.value),
                  top: lerpDouble(_dragEndPosition!.dy, _itemOriginalPosition!.dy, _returnAnimationController!.value),
                  child: _returningWidget!,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
