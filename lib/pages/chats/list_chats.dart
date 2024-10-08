import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import

import 'package:rolachat/pages/chats/chat_page.dart';

class ListChats extends StatefulWidget {
  const ListChats({super.key});

  @override
  State<ListChats> createState() => _ListChatsState();
}

class _ListChatsState extends State<ListChats> {
  late Stream<QuerySnapshot> _chatroomsStream;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _setupChatroomsStream();
  }

  void _setupChatroomsStream() {
    _chatroomsStream = FirebaseFirestore.instance
        .collection('chatrooms')
        .where('participants', arrayContains: currentUserId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatroomsStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Something went wrong'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        return ListView(
          children: snapshot.data!.docs.map((DocumentSnapshot document) {
            Map<String, dynamic> chatroom =
                document.data()! as Map<String, dynamic>;
            List<dynamic> participants = chatroom['participants'];
            String otherUserId =
                participants.firstWhere((id) => id != currentUserId);

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('Users')
                  .doc(otherUserId)
                  .get(),
              builder: (BuildContext context,
                  AsyncSnapshot<DocumentSnapshot> userSnapshot) {
                if (userSnapshot.hasError || !userSnapshot.hasData) {
                  return ListTile(title: Text('Error loading user data'));
                }

                Map<String, dynamic> userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chatrooms')
                      .doc(document.id)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, messagesSnapshot) {
                    String lastMessageText = '';
                    String lastMessageStatus = 'sent';
                    int unreadCount = 0;

                    if (messagesSnapshot.hasData &&
                        messagesSnapshot.data!.docs.isNotEmpty) {
                      var lastMessage = messagesSnapshot.data!.docs.first.data()
                          as Map<String, dynamic>;
                      lastMessageText = lastMessage['text'] ?? '';
                      lastMessageStatus = lastMessage['status'] ?? 'sent';
                    }

                    return FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('chatrooms')
                          .doc(document.id)
                          .collection('messages')
                          .where('receiverId', isEqualTo: currentUserId)
                          .where('status',
                              whereIn: ['sent', 'delivered']).get(),
                      builder: (context, unreadSnapshot) {
                        if (unreadSnapshot.hasData) {
                          unreadCount = unreadSnapshot.data!.docs.length;
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(
                                userData['photo'] ?? '/assets/images/logo.png'),
                          ),
                          title: Text(userData['name']),
                          subtitle: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastMessageText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                lastMessageStatus == 'read'
                                    ? Icons.done_all
                                    : lastMessageStatus == 'delivered'
                                        ? Icons.done_all
                                        : Icons.done,
                                size: 16,
                                color: lastMessageStatus == 'read'
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                            ],
                          ),
                          trailing: unreadCount > 0
                              ? Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ChatPage(selectedUserId: otherUserId),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}
