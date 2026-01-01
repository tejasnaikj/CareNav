import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import '../../../../core/services/firebase_service.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;
  final String patientName;
  final String doctorName;

  const SessionDetailScreen({
    super.key,
    required this.sessionId,
    required this.patientName,
    required this.doctorName,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final FirebaseService _firebase = FirebaseService.instance;
  final FlutterTts _flutterTts = FlutterTts();
  bool _showingSummary = true;
  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _drawings = [];
  bool _loading = true;
  String? _speakingMessageId;

  @override
  void initState() {
    super.initState();
    _initTts();
    print('🔍 SessionDetailScreen: Loading session ${widget.sessionId}');
    _loadSessionData();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setCompletionHandler(() {
      setState(() => _speakingMessageId = null);
    });
  }

  Future<void> _speak(String text, String messageId, bool isKannada) async {
    if (_speakingMessageId == messageId) {
      await _flutterTts.stop();
      setState(() => _speakingMessageId = null);
    } else {
      await _flutterTts.stop();
      
      if (isKannada) {
        await _flutterTts.setLanguage("kn-IN");
      } else {
        await _flutterTts.setLanguage("en-US");
      }
      
      setState(() => _speakingMessageId = messageId);
      await _flutterTts.speak(text);
    }
  }

  Future<void> _loadSessionData() async {
    setState(() => _loading = true);

    try {
      print('🔍 Fetching session data...');
      final session = await _firebase.getSession(widget.sessionId);
      
      if (session == null) {
        print('❌ Session not found: ${widget.sessionId}');
        setState(() => _loading = false);
        return;
      }

      print('✅ Session found: ${session['patientName']}');

      final messagesSnapshot = await _firebase.firestore
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('messages')
          .get();

      final messages = messagesSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      messages.sort((a, b) {
        final aTime = a['timestamp'] ?? '';
        final bTime = b['timestamp'] ?? '';
        return aTime.toString().compareTo(bTime.toString());
      });

      print('✅ Found ${messages.length} messages');

      final drawings = await _firebase.getSessionDrawings(widget.sessionId);
      print('✅ Found ${drawings.length} drawings');

      setState(() {
        _session = session;
        _messages = messages;
        _drawings = drawings;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading session: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Session: ${widget.patientName}'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade500],
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _session == null
              ? const Center(child: Text('Session not found'))
              : _showingSummary
                  ? _buildSummaryView()
                  : _buildChatHistoryView(),
    );
  }

  Widget _buildSummaryView() {
    if (_session == null) {
      return const Center(child: Text('Session not found'));
    }

    final startTime = DateTime.parse(_session!['startTime'] ?? DateTime.now().toIso8601String());
    final endTime = _session!['endTime'] != null ? DateTime.parse(_session!['endTime']) : null;
    final duration = endTime != null ? endTime.difference(startTime) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.medical_services, color: Colors.white, size: 40),
                    SizedBox(width: 16),
                    Text(
                      'Session Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSummaryRow(Icons.person, 'Patient', widget.patientName),
                const SizedBox(height: 12),
                _buildSummaryRow(Icons.local_hospital, 'Doctor', widget.doctorName),
                const SizedBox(height: 12),
                _buildSummaryRow(
                  Icons.calendar_today,
                  'Date',
                  DateFormat('MMM dd, yyyy').format(startTime),
                ),
                const SizedBox(height: 12),
                _buildSummaryRow(
                  Icons.access_time,
                  'Start Time',
                  DateFormat('hh:mm a').format(startTime),
                ),
                if (endTime != null) ...[
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    Icons.access_time_filled,
                    'End Time',
                    DateFormat('hh:mm a').format(endTime),
                  ),
                ],
                if (duration != null) ...[
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    Icons.timer,
                    'Duration',
                    '${duration.inMinutes} minutes',
                  ),
                ],
                const SizedBox(height: 12),
                _buildSummaryRow(Icons.chat, 'Messages', '${_messages.length}'),
                const SizedBox(height: 12),
                _buildSummaryRow(Icons.draw, 'Drawings', '${_drawings.length}'),
              ],
            ),
          ),

          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: () {
              setState(() => _showingSummary = false);
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('View Chat History', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatHistoryView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade700,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() => _showingSummary = true);
                },
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Chat History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No messages in this session', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isDoctor = message['sender'] == 'doctor';

                    Widget? dateDivider;
                    if (index == 0 || _isDifferentDay(_messages[index - 1], message)) {
                      dateDivider = _buildDateDivider(message['timestamp']);
                    }

                    return Column(
                      children: [
                        if (dateDivider != null) dateDivider,
                        _buildMessageBubble(message, isDoctor),
                      ],
                    );
                  },
                ),
        ),

        if (_drawings.isNotEmpty) _buildDrawingsGallery(),
      ],
    );
  }

  bool _isDifferentDay(Map<String, dynamic> msg1, Map<String, dynamic> msg2) {
    try {
      final date1 = DateTime.parse(msg1['timestamp']);
      final date2 = DateTime.parse(msg2['timestamp']);
      return date1.day != date2.day || date1.month != date2.month || date1.year != date2.year;
    } catch (e) {
      return false;
    }
  }

  Widget _buildDateDivider(String timestamp) {
    final date = DateTime.parse(timestamp);
    final now = DateTime.now();
    String dateText;

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      dateText = 'Today';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMM dd, yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isDoctor) {
    final text = message['text']?.toString() ?? '';
    final translatedText = message['translatedText']?.toString() ?? '';
    final senderName = message['senderName']?.toString() ?? 'Unknown';
    final timestamp = message['timestamp'] != null ? DateTime.parse(message['timestamp']) : DateTime.now();
    final messageId = message['id'];

    return Align(
      alignment: isDoctor ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: isDoctor ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDoctor ? Icons.medical_services : Icons.person,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDoctor
                      ? [Colors.blue.shade400, Colors.blue.shade600]
                      : [Colors.green.shade400, Colors.green.shade600],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isDoctor ? 20 : 4),
                  bottomRight: Radius.circular(isDoctor ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _speak(text, '${messageId}_en', false),
                        child: Icon(
                          _speakingMessageId == '${messageId}_en' ? Icons.stop_circle : Icons.volume_up,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  if (translatedText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            translatedText,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _speak(translatedText, '${messageId}_kn', true),
                          child: Icon(
                            _speakingMessageId == '${messageId}_kn' ? Icons.stop_circle : Icons.volume_up,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('hh:mm a').format(timestamp),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawingsGallery() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.draw, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Drawings (${_drawings.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _drawings.length,
              itemBuilder: (context, index) {
                final drawing = _drawings[index];
                return GestureDetector(
                  onTap: () {
                    _showDrawingDialog(drawing);
                  },
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Container(
                              color: Colors.white,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: _buildDrawingPreview(drawing, const Size(400, 600)),
                              ),
                            ),
                          ),
                        ),
                        if (drawing['notes'] != null && drawing['notes'].toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            ),
                            child: Text(
                              drawing['notes'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingPreview(Map<String, dynamic> drawing, Size size) {
    try {
      final imageData = drawing['imageData'];
      if (imageData == null) {
        return Container(
          width: size.width,
          height: size.height,
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.draw, size: 40, color: Colors.blue)),
        );
      }

      final data = jsonDecode(imageData);
      final points = data['points'] as List<dynamic>?;
      
      if (points == null || points.isEmpty) {
        return Container(
          width: size.width,
          height: size.height,
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.draw, size: 40, color: Colors.blue)),
        );
      }

      return SizedBox(
        width: size.width,
        height: size.height,
        child: CustomPaint(
          painter: DrawingPainter(points),
          size: size,
        ),
      );
    } catch (e) {
      print('Error rendering drawing preview: $e');
      return Container(
        width: size.width,
        height: size.height,
        color: Colors.grey.shade200,
        child: const Center(child: Icon(Icons.error, size: 40, color: Colors.red)),
      );
    }
  }

  void _showDrawingDialog(Map<String, dynamic> drawing) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.draw, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Drawing',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Container(
                height: MediaQuery.of(context).size.height * 0.6,
                width: double.infinity,
                color: Colors.white,
                child: InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: _buildDrawingPreview(drawing, const Size(400, 800)),
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (drawing['notes'] != null && drawing['notes'].toString().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.note, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Notes:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(drawing['notes']),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Created: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(drawing['timestamp']))}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in, size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Pinch to zoom • Drag to move',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<dynamic> points;

  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      final point1 = points[i];
      final point2 = points[i + 1];

      if (point1 == null || point2 == null) continue;

      try {
        final x1 = (point1['x'] as num).toDouble();
        final y1 = (point1['y'] as num).toDouble();
        final x2 = (point2['x'] as num).toDouble();
        final y2 = (point2['y'] as num).toDouble();
        final colorValue = point1['color'] as int;
        final strokeWidth = (point1['width'] as num).toDouble();

        final paint = Paint()
          ..color = Color(colorValue)
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(x1, y1),
          Offset(x2, y2),
          paint,
        );
      } catch (e) {
        print('Error painting point: $e');
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
