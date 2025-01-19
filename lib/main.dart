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
class Dock<T> extends StatefulWidget {
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

/// State of the [Dock] used to manipulate the [_items].
class _DockState<T> extends State<Dock<T>> {
  /// [T] items being manipulated.
  late final List<T> _items = widget.items.toList();
  int? _hoveredIndex;
  
  double _getPropertyValue({
    required int index,
    required double baseValue,
    required double maxValue,
    required double nonHoveredMaxValue,
    required int? hoveredIndex,
  }) {
    if (hoveredIndex == null) return baseValue;
    
    final difference = (hoveredIndex - index).abs();
    if (difference == 0) return maxValue;
    
    const itemsAffected = 2;
    if (difference <= itemsAffected) {
      final ratio = (itemsAffected - difference) / itemsAffected;
      return lerpDouble(baseValue, nonHoveredMaxValue, ratio)!;
    }
    
    return baseValue;
  }

  double _getScale(int index) {
    return _getPropertyValue(
      index: index,
      baseValue: 1.0,
      maxValue: 1.3,
      nonHoveredMaxValue: 1.1,
      hoveredIndex: _hoveredIndex,
    );
  }

  double _getTranslationY(int index) {
    return _getPropertyValue(
      index: index,
      baseValue: 0,
      maxValue: -10,
      nonHoveredMaxValue: -6,
      hoveredIndex: _hoveredIndex,
    );
  }

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
              transform: Matrix4.identity()
                ..scale(_getScale(index))
                ..translate(0, _getTranslationY(index)),
              child: widget.builder(_items[index]),
            ),
          );
        }),
      ),
    );
  }
}
