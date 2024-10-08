import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rolachat/pages/chats/ai_chat.dart';
import 'package:rolachat/pages/chats/chat_page.dart';
import 'package:rolachat/pages/chats/list_chats.dart';
import 'package:rolachat/settings/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Define the pages/tabs for the bottom navbar
  static const List<Widget> _pages = <Widget>[
    ListChats(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: 300,
            height: 400,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Search User',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Expanded(child: SearchUserWidget()),
                TextButton(
                  child: Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rolachat'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              // Handle menu item selection
              switch (value) {
                case 'New group':
                  // TODO: Implement new group functionality
                  break;
                case 'New broadcast':
                  // TODO: Implement new broadcast functionality
                  break;
                case 'Linked devices':
                  // TODO: Implement linked devices functionality
                  break;
                case 'Starred messages':
                  // TODO: Implement starred messages functionality
                  break;
                case 'aichat':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AiChat()),
                  );
                  break;

                case 'Logout':
                  await FirebaseAuth.instance.signOut();
                  final googleSignIn = GoogleSignIn();
                  await googleSignIn.signOut();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'New group',
                child: Text('New group'),
              ),
              const PopupMenuItem<String>(
                value: 'New broadcast',
                child: Text('New broadcast'),
              ),
              const PopupMenuItem<String>(
                value: 'Linked devices',
                child: Text('Linked devices'),
              ),
              const PopupMenuItem<String>(
                value: 'Starred messages',
                child: Text('Starred messages'),
              ),
              const PopupMenuItem<String>(
                value: 'Logout',
                child: Text('Logout'),
              ),
              const PopupMenuItem<String>(
                value: 'aichat',
                child: Text('AI Chat'),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _pages,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _showSearchDialog,
            child: Icon(Icons.search, color: Colors.white),
            backgroundColor: Colors.green,
            heroTag: 'search',
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AiChat()),
              );
            },
            child: Icon(Icons.smart_toy),
            // backgroundColor: Colors.purple,
            heroTag: 'aiChat',
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(_selectedIndex == 0
                    ? Icons.chat_bubble
                    : Icons.chat_bubble_outline),
                label: 'Chats',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                    _selectedIndex == 1 ? Icons.person : Icons.person_outline),
                label: 'Profile',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.green,
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.normal),
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }
}

class SearchUserWidget extends StatefulWidget {
  @override
  _SearchUserWidgetState createState() => _SearchUserWidgetState();
}

class _SearchUserWidgetState extends State<SearchUserWidget> {
  final TextEditingController _searchController = TextEditingController();
  Stream<QuerySnapshot>? _usersStream;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _usersStream = null;
      });
    } else {
      final currentUser = FirebaseAuth.instance.currentUser;
      setState(() {
        _usersStream = FirebaseFirestore.instance
            .collection('Users')
            .where(Filter.or(
                Filter.and(
                    Filter('username',
                        isGreaterThanOrEqualTo: _searchController.text),
                    Filter('username',
                        isLessThan: _searchController.text + 'z')),
                Filter.and(
                    Filter('email',
                        isGreaterThanOrEqualTo: _searchController.text),
                    Filter('email', isLessThan: _searchController.text + 'z'))))
            .where('email', isNotEqualTo: currentUser?.email)
            .limit(10)
            .snapshots();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Enter username or email',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        SizedBox(height: 10),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _usersStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                print('Error in StreamBuilder: ${snapshot.error}');
                return Text('Error: ${snapshot.error}');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Text('No users found');
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  try {
                    DocumentSnapshot document = snapshot.data!.docs[index];
                    Map<String, dynamic> data =
                        document.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['name'] ?? 'No name'),
                      subtitle: Text(data['email'] ?? 'No email'),
                      onTap: () {
                        Navigator.of(context).pop(); // Close the dialog
                        // Navigate to the chat page with the selected user
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              selectedUserId: data['uid'],
                            ),
                          ),
                        );
                      },
                    );
                  } catch (e) {
                    print('Error rendering list item: $e');
                    return ListTile(
                      title: Text('Error displaying user'),
                      subtitle: Text('Please try again'),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
