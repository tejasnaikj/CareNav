import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../drawing/presentation/screens/drawing_board_screen.dart';
import '../../../prescription/presentation/widgets/prescription_widget.dart';

class RealtimeSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final User doctor;
  final String patientId;
  final String patientName;

  const RealtimeSessionScreen({
    super.key,
    required this.sessionId,
    required this.doctor,
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<RealtimeSessionScreen> createState() => _RealtimeSessionScreenState();
}

class _RealtimeSessionScreenState extends ConsumerState<RealtimeSessionScreen> with SingleTickerProviderStateMixin {
  final GoogleTranslator _translator = GoogleTranslator();
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FirebaseService _firebase = FirebaseService.instance;
  final TextEditingController _textController = TextEditingController();
  
  late TabController _tabController;
  bool _isListening = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeSpeech();
    _initializeTts();
  }

  Future<void> _initializeSpeech() async {
    await _speech.initialize();
  }

  Future<void> _initializeTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _textController.dispose();
    _tabController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final translation = await _translator.translate(text, from: 'en', to: 'kn');
      
      final message = {
        'text': text,
        'translatedText': translation.text,
        'sender': 'doctor',
        'senderName': widget.doctor.fullName,
        'language': 'en',
        'translatedLanguage': 'kn',
      };

      await _firebase.sendMessage(widget.sessionId, message);
      _textController.clear();
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _textController.text = result.recognizedWords;
            });
          },
          localeId: 'en-US',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _speak(String text, String language) async {
    try {
      await _tts.setLanguage(language == 'en' ? 'en-US' : 'kn-IN');
      await _tts.speak(text);
    } catch (e) {
      print('TTS error: $e');
    }
  }

  Future<void> _endSession() async {
    // Step 1: Ask about transport
    final needTransport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transportation'),
        content: const Text('Does the patient need transportation assistance?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (needTransport == true) {
      // Send transport request to admin
      await _firebase.firestore.collection('transport_requests').add({
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'doctorId': widget.doctor.id,
        'sessionId': widget.sessionId,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'pending',
      });
    }

    // Step 2: Ask about next location
    final giveLocation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Navigation'),
        content: const Text('Provide next location for patient navigation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (giveLocation == true && mounted) {
      final locationController = TextEditingController();
      final location = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enter Location'),
          content: TextField(
            controller: locationController,
            decoration: const InputDecoration(
              hintText: 'e.g., Pharmacy, Exit, Ward 3',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, locationController.text),
              child: const Text('Set'),
            ),
          ],
        ),
      );

      if (location != null && location.isNotEmpty) {
        await _firebase.firestore.collection('navigation').add({
          'patientId': widget.patientId,
          'destination': location,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }

    // Step 3: Ask about prescription
    final editPrescription = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prescription'),
        content: const Text('Do you want to review/edit the prescription?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (editPrescription == true) {
      _tabController.animateTo(2); // Go to prescription tab
      return; // Don't end session yet
    }

    // Step 4: Permanently end session
    await _firebase.updateSession(widget.sessionId, {
      'status': 'completed',
      'endTime': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session: ${widget.patientName}'),
            Text('Dr. ${widget.doctor.fullName}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade500],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Leave Temporarily',
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle),
            tooltip: 'End Session',
            onPressed: _endSession,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: 'Chat'),
            Tab(icon: Icon(Icons.draw), text: 'Draw'),
            Tab(icon: Icon(Icons.medication), text: 'Rx'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatTab(),
          DrawingBoardScreen(sessionId: widget.sessionId),
          PrescriptionWidget(
            doctorId: widget.doctor.id,
            patientId: widget.patientId,
            patientName: widget.patientName,
            sessionId: widget.sessionId,
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder(
            stream: _firebase.watchSessionMessages(widget.sessionId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No messages yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                );
              }

              final messages = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                reverse: false,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final doc = messages[index];
                  final message = doc.data() as Map<String, dynamic>;
                  final isDoctor = message['sender'] == 'doctor';

                  return _buildMessageBubble(message, isDoctor);
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _isListening ? Colors.red : Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
                  onPressed: _startListening,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Type message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onSubmitted: _sendMessage,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: _isSending ? null : () => _sendMessage(_textController.text),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isDoctor) {
    final text = message['text']?.toString() ?? '';
    final translatedText = message['translatedText']?.toString() ?? '';
    final senderName = message['senderName']?.toString() ?? 'Unknown';

    return Align(
      alignment: isDoctor ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
                boxShadow: [
                  BoxShadow(
                    color: (isDoctor ? Colors.blue : Colors.green).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                      IconButton(
                        icon: const Icon(Icons.volume_up, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _speak(text, isDoctor ? 'en' : 'kn'),
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
                        IconButton(
                          icon: const Icon(Icons.volume_up, color: Colors.white70, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _speak(translatedText, isDoctor ? 'kn' : 'en'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
