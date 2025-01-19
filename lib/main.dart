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

/// State of the [Dock] used to manipulate the [_items].
class _DockState<T extends Object> extends State<Dock<T>> {
  /// [T] items being manipulated.
  late final List<T> _items = widget.items.toList();
  int? _hoveredIndex;
  
  // Tworzymy jedną instancję dla wszystkich elementów
  final _animation = const DockItemAnimation();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black12,
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_items.length, (index) {
          return MouseRegion(
            onEnter: (_) => setState(() => _hoveredIndex = index),
            onExit: (_) => setState(() => _hoveredIndex = null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transformAlignment: Alignment.center,
              transform: _animation.getTransform(index, _hoveredIndex),
              child: widget.builder(_items[index]),
            ),
          );
        }),
      ),
    );
  }
}
