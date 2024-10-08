import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;

class AiChat extends StatefulWidget {
  const AiChat({super.key});

  @override
  State<AiChat> createState() => _AiChatState();
}

class _AiChatState extends State<AiChat> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late GenerativeModel _model;
  late ChatSession _chat;
  late Stream<QuerySnapshot> _messagesStream;
  late String _chatId;
  bool _isAiTyping = false;
  bool _showEmoji = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmoji = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _initializeChat() async {
    const apiKey = ''; // Replace with your actual API key
    _model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
    _chat = _model.startChat();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _chatId = 'ai_${user.uid}';
      _setupMessagesStream();
    } else {
      // Handle the case when the user is not logged in
      print('User is not logged in');
    }
  }

  void _setupMessagesStream() {
    _messagesStream = FirebaseFirestore.instance
        .collection('chatrooms')
        .doc(_chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  void _toggleEmojiKeyboard() {
    setState(() {
      _showEmoji = !_showEmoji;
    });
    if (_showEmoji) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _sendMessage() async {
    if (_textController.text.isEmpty) return;

    final userMessage = _textController.text;
    _textController.clear();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Add user message to Firestore
      await FirebaseFirestore.instance
          .collection('chatrooms')
          .doc(_chatId)
          .collection('messages')
          .add({
        'text': userMessage,
        'isUser': true,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
      });

      // Show "AI is typing..." message
      setState(() {
        _isAiTyping = true;
      });

      // Get AI response
      final response = await _chat.sendMessage(Content.text(userMessage));

      // Hide "AI is typing..." message
      setState(() {
        _isAiTyping = false;
      });

      // Add AI response to Firestore
      await FirebaseFirestore.instance
          .collection('chatrooms')
          .doc(_chatId)
          .collection('messages')
          .add({
        'text': response.text ?? 'No response',
        'isUser': false,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': 'AI',
      });
    } catch (e) {
      print('Error sending message: $e');
      // Hide "AI is typing..." message in case of error
      setState(() {
        _isAiTyping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rola AI Chat')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                final messages = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ChatMessage(
                    text: data['text'] as String,
                    isUser: data['isUser'] as bool,
                  );
                }).toList();

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length + (_isAiTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == 0 && _isAiTyping) {
                      return MessageBubble(
                        message: ChatMessage(
                          text: 'Rola is typing...',
                          isUser: false,
                        ),
                      );
                    }
                    return MessageBubble(
                      message: messages[_isAiTyping ? index - 1 : index],
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: _buildTextComposer(),
          ),
          Offstage(
            offstage: !_showEmoji,
            child: SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (Category? category, Emoji emoji) {
                  _textController.text += emoji.emoji;
                },
                onBackspacePressed: () {
                  _textController
                    ..text =
                        _textController.text.characters.skipLast(1).toString()
                    ..selection = TextSelection.fromPosition(
                        TextPosition(offset: _textController.text.length));
                },
                textEditingController: _textController,
                config: Config(
                  height: 256,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    emojiSizeMax: 28 *
                        (foundation.defaultTargetPlatform == TargetPlatform.iOS
                            ? 1.20
                            : 1.0),
                  ),
                  // ... other config options ...
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25.0),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, 3),
                    blurRadius: 5,
                    color: Colors.grey.withOpacity(0.3),
                  )
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _showEmoji ? Icons.keyboard : Icons.emoji_emotions,
                      color: Colors.grey[600],
                    ),
                    onPressed: _toggleEmojiKeyboard,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      onSubmitted: (text) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10.0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          Container(
            decoration: const BoxDecoration(
              color: Colors.teal,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
