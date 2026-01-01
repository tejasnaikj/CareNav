import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import '../../../../core/services/firebase_service.dart';

class DrawingBoardScreen extends StatefulWidget {
  final String sessionId;
  const DrawingBoardScreen({super.key, required this.sessionId});

  @override
  State<DrawingBoardScreen> createState() => _DrawingBoardScreenState();
}

class _DrawingBoardScreenState extends State<DrawingBoardScreen> {
  List<DrawingPoint> drawingPoints = [];
  Color selectedColor = Colors.black;
  double strokeWidth = 5.0;
  final FirebaseService _firebase = FirebaseService.instance;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Drawing Canvas
          GestureDetector(
            onPanStart: (details) {
              setState(() {
                drawingPoints.add(
                  DrawingPoint(
                    details.localPosition,
                    Paint()
                      ..color = selectedColor
                      ..strokeWidth = strokeWidth
                      ..strokeCap = StrokeCap.round,
                  ),
                );
              });
            },
            onPanUpdate: (details) {
              setState(() {
                drawingPoints.add(
                  DrawingPoint(
                    details.localPosition,
                    Paint()
                      ..color = selectedColor
                      ..strokeWidth = strokeWidth
                      ..strokeCap = StrokeCap.round,
                  ),
                );
              });
            },
            onPanEnd: (details) {
              setState(() {
                drawingPoints.add(DrawingPoint(null, Paint()));
              });
            },
            child: CustomPaint(
              painter: DrawingPainter(drawingPoints),
              size: Size.infinite,
            ),
          ),

          // Toolbar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Color Picker
                    _buildColorButton(Colors.black),
                    _buildColorButton(Colors.red),
                    _buildColorButton(Colors.blue),
                    _buildColorButton(Colors.green),
                    _buildColorButton(Colors.yellow),
                    
                    const VerticalDivider(),
                    
                    // Stroke Width
                    IconButton(
                      icon: Icon(
                        strokeWidth == 5.0 ? Icons.brush : Icons.format_size,
                        color: Colors.blue,
                      ),
                      onPressed: () {
                        setState(() {
                          strokeWidth = strokeWidth == 5.0 ? 10.0 : 5.0;
                        });
                      },
                      tooltip: strokeWidth == 5.0 ? 'Thick' : 'Thin',
                    ),
                    
                    // Eraser
                    IconButton(
                      icon: Icon(
                        Icons.auto_fix_high,
                        color: selectedColor == Colors.white ? Colors.blue : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          selectedColor = Colors.white;
                          strokeWidth = 20.0;
                        });
                      },
                      tooltip: 'Eraser',
                    ),
                    
                    // Clear
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          drawingPoints.clear();
                        });
                      },
                      tooltip: 'Clear All',
                    ),
                    
                    // Save
                    _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.save, color: Colors.green),
                            onPressed: drawingPoints.isEmpty ? null : _saveDrawing,
                            tooltip: 'Save Drawing',
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedColor = color;
          if (color != Colors.white) {
            strokeWidth = 5.0;
          }
        });
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selectedColor == color ? Colors.blue : Colors.grey,
            width: selectedColor == color ? 3 : 1,
          ),
        ),
      ),
    );
  }

  Future<void> _saveDrawing() async {
    if (drawingPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to save!')),
      );
      return;
    }

    // Show dialog to ask for notes
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => _NotesDialog(),
    );

    // User cancelled
    if (notes == null) return;

    setState(() => _isSaving = true);

    try {
      // Convert drawing to base64 (simplified - just save points data)
      final drawingData = jsonEncode({
        'points': drawingPoints.map((p) {
          if (p.offset == null) return null;
          return {
            'x': p.offset!.dx,
            'y': p.offset!.dy,
            'color': p.paint.color.value,
            'width': p.paint.strokeWidth,
          };
        }).toList(),
      });

      await _firebase.saveDrawing(
        widget.sessionId,
        drawingData,
        notes.isEmpty ? null : notes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Drawing saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Clear the canvas after saving
        setState(() {
          drawingPoints.clear();
        });
      }
    } catch (e) {
      print('Error saving drawing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving drawing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }
}

class _NotesDialog extends StatefulWidget {
  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  final TextEditingController _notesController = TextEditingController();
  bool _hasNotes = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Drawing'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Would you like to add notes to this drawing?'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _hasNotes = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_hasNotes ? Colors.blue : Colors.grey.shade300,
                    foregroundColor: !_hasNotes ? Colors.white : Colors.black,
                  ),
                  child: const Text('No Notes'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _hasNotes = true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasNotes ? Colors.blue : Colors.grey.shade300,
                    foregroundColor: _hasNotes ? Colors.white : Colors.black,
                  ),
                  child: const Text('Add Notes'),
                ),
              ),
            ],
          ),
          if (_hasNotes) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter notes here...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, _hasNotes ? _notesController.text : '');
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class DrawingPoint {
  Offset? offset;
  Paint paint;

  DrawingPoint(this.offset, this.paint);
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  DrawingPainter(this.drawingPoints);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < drawingPoints.length - 1; i++) {
      if (drawingPoints[i].offset != null && drawingPoints[i + 1].offset != null) {
        canvas.drawLine(
          drawingPoints[i].offset!,
          drawingPoints[i + 1].offset!,
          drawingPoints[i].paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
