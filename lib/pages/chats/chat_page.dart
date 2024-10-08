import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  final String selectedUserId;

  const ChatPage({super.key, required this.selectedUserId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showEmoji = false;
  late Future<DocumentSnapshot> _userDataFuture;
  late String _chatroomId;
  Stream<QuerySnapshot>? _messagesStream; // Change to nullable

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmoji = false;
        });
      }
    });
    _userDataFuture = FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.selectedUserId)
        .get();
    _setupChatroom();
  }

  void _setupChatroom() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Create a unique chatroom ID
    List<String> ids = [currentUser.uid, widget.selectedUserId];
    ids.sort(); // Sort to ensure consistency
    _chatroomId = ids.join('_');

    // Create or get the chatroom document
    final chatroomRef =
        FirebaseFirestore.instance.collection('chatrooms').doc(_chatroomId);
    await chatroomRef.set({
      'participants': [currentUser.uid, widget.selectedUserId],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Add a listener for message updates
    chatroomRef.collection('messages').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          var message = change.doc.data() as Map<String, dynamic>;
          if (message['receiverId'] == currentUser.uid &&
              message['status'] != 'read') {
            // Update message status to 'read' if the current user is the receiver
            change.doc.reference.update({'status': 'read'});
          }
        }
      }
    });

    // Set up the messages stream
    setState(() {
      _messagesStream = chatroomRef
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots();
    });

    // Mark messages as read when the current user opens the chat
    _markMessagesAsRead(currentUser.uid);
  }

  void _markMessagesAsRead(String currentUserId) {
    FirebaseFirestore.instance
        .collection('chatrooms')
        .doc(_chatroomId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .get()
        .then((querySnapshot) {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        if (doc['status'] != 'read') {
          batch.update(doc.reference, {'status': 'read'});
        }
      }
      return batch.commit();
    }).then((_) {
      print('Messages marked as read');
    }).catchError((error) {
      print('Error marking messages as read: $error');
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();

    FirebaseFirestore.instance
        .collection('chatrooms')
        .doc(_chatroomId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': FirebaseAuth.instance.currentUser!.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
      'receiverId': widget.selectedUserId,
    });

    // Update last message in chatroom document
    FirebaseFirestore.instance.collection('chatrooms').doc(_chatroomId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _userDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text('Loading...')),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text('Error')),
            body: Center(child: Text('An error occurred')),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(
                      userData['photo'] ?? '/assets/images/logo.png'),
                ),
                const SizedBox(width: 10),
                Text(
                  userData['name'],
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
            backgroundColor: Colors.teal,
          ),
          body: Column(
            children: [
              Expanded(
                child: _messagesStream == null
                    ? Center(child: CircularProgressIndicator())
                    : StreamBuilder<QuerySnapshot>(
                        stream: _messagesStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Center(child: Text('No messages yet'));
                          }

                          final messages = snapshot.data!.docs;
                          return ListView.builder(
                            reverse: true,
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index].data()
                                  as Map<String, dynamic>;
                              final isMe = message['senderId'] ==
                                  FirebaseAuth.instance.currentUser!.uid;
                              return ChatMessage(
                                status: message['status'] ?? '',
                                text: message['text'] ?? '',
                                isMe: isMe,
                                isViewed: true, // Added required parameter
                                timestamp: message['timestamp'] != null
                                    ? (message['timestamp'] as Timestamp)
                                        .toDate()
                                    : DateTime.now(),
                                userData: userData,
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
                        ..text = _textController.text.characters
                            .skipLast(1)
                            .toString()
                        ..selection = TextSelection.fromPosition(
                            TextPosition(offset: _textController.text.length));
                    },
                    textEditingController: _textController,
                    config: Config(
                      height: 256,
                      checkPlatformCompatibility: true,
                      emojiViewConfig: EmojiViewConfig(
                        // Issue: https://github.com/flutter/flutter/issues/28894
                        emojiSizeMax: 28 *
                            (foundation.defaultTargetPlatform ==
                                    TargetPlatform.iOS
                                ? 1.20
                                : 1.0),
                      ),
                      viewOrderConfig: const ViewOrderConfig(
                        top: EmojiPickerItem.categoryBar,
                        middle: EmojiPickerItem.emojiView,
                        bottom: EmojiPickerItem.searchBar,
                      ),
                      skinToneConfig: const SkinToneConfig(),
                      categoryViewConfig: const CategoryViewConfig(),
                      bottomActionBarConfig: const BottomActionBarConfig(),
                      searchViewConfig: const SearchViewConfig(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
                      onSubmitted: _handleSubmitted,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10.0),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.attach_file, color: Colors.grey[600]),
                    onPressed: () {
                      // TODO: Implement file attachment
                    },
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
              onPressed: () => _handleSubmitted(_textController.text),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final Map<String, dynamic> userData;
  final bool isViewed; // Add this line
  final String status; // Add this line

  const ChatMessage({
    Key? key,
    required this.text,
    required this.isMe,
    required this.timestamp,
    required this.userData,
    required this.isViewed, // Add this line
    required this.status, // Add this line
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _buildAvatar(),
          Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: isMe ? Colors.blue : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  text,
                  style: TextStyle(color: isMe ? Colors.white : Colors.black),
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (isMe) SizedBox(width: 4),
                  if (isMe) _buildMessageStatus(),
                ],
              ),
            ],
          ),
          if (isMe) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildMessageStatus() {
    if (!isMe) return SizedBox.shrink();

    IconData icon;
    Color color;

    switch (status) {
      case 'sent':
        icon = Icons.check;
        color = Colors.grey[600]!;
        break;
      case 'delivered':
        icon = Icons.done_all;
        color = Colors.grey[600]!;
        break;
      case 'read':
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      default:
        icon = Icons.access_time;
        color = Colors.grey[600]!;
    }

    return Icon(
      icon,
      size: 16,
      color: color,
    );
  }

  Widget _buildAvatar() {
    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      child: CircleAvatar(
        backgroundImage: NetworkImage(
          isMe
              ? FirebaseAuth.instance.currentUser?.photoURL ??
                  'assets/images/default_avatar.png'
              : userData['photo'] ?? 'assets/images/default_avatar.png',
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    // Convert to 12-hour format
    int hour = timestamp.hour % 12;
    hour = hour == 0 ? 12 : hour; // Handle midnight (0:00)
    String period = timestamp.hour < 12 ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} $period';
  }
}
