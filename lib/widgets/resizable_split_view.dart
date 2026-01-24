import 'package:flutter/material.dart';

class ResizableSplitView extends StatefulWidget {
  final Widget topChild;
  final Widget bottomChild;
  final double initialRatio;

  const ResizableSplitView({
    super.key,
    required this.topChild,
    required this.bottomChild,
    this.initialRatio = 0.5,
  });

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  late double _ratio;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        // Ensure ratio stays within reasonable bounds
        final safeRatio = _ratio.clamp(0.1, 0.9);

        // Calculate Top Height based on ratio
        double topHeight = totalHeight * safeRatio;

        // Safety check: When keyboard opens, totalHeight shrinks.
        // We must ensure the Bottom Child (Command Panel) has enough space to be usable.
        // If bottom space < minBottomHeight, we reduce topHeight.
        const minBottomHeight = 200.0;
        const dragHandleHeight = 24.0;

        if (totalHeight - dragHandleHeight - topHeight < minBottomHeight) {
          topHeight = totalHeight - dragHandleHeight - minBottomHeight;
          // If total height is REALLY small (e.g. < 224), topHeight might become negative.
          if (topHeight < 0) topHeight = 0;
        }

        return Column(
          children: [
            SizedBox(height: topHeight, child: widget.topChild),
            GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() {
                  _ratio += details.delta.dy / totalHeight;
                });
              },
              child: Container(
                height: dragHandleHeight, // Drag handle height
                width: double.infinity,
                color: Colors.grey.shade200,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: widget.bottomChild),
          ],
        );
      },
    );
  }
}
