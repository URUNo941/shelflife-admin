import 'package:flutter/material.dart';

class UserManagementView extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const UserManagementView({super.key, this.onBackToDashboard});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  String searchQuery = '';
  String selectedRole = 'All';

  // Mock data รายชื่อผู้ใช้
  final List<Map<String, String>> usersList = [
    {'username': 'tom123', 'role': 'Admin', 'joinedDate': 'Oct 1, 2026'},
    {'username': 'sarah', 'role': 'User', 'joinedDate': 'Oct 5, 2026'},
    {'username': 'john', 'role': 'User', 'joinedDate': 'Oct 10, 2026'},
    {'username': 'patlee', 'role': 'User', 'joinedDate': 'Oct 12, 2026'},
    {'username': 'natsirin', 'role': 'User', 'joinedDate': 'Oct 15, 2026'},
    {'username': 'ployk', 'role': 'User', 'joinedDate': 'Oct 18, 2026'},
    {'username': 'winm', 'role': 'User', 'joinedDate': 'Oct 20, 2026'},
  ];

  Future<Map<String, String>?> _showUserEditor({
    Map<String, String>? user,
  }) async {
    final formKey = GlobalKey<FormState>();
    var username = user?['username'] ?? '';
    var role = user?['role'] ?? 'User';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user == null ? 'Add user' : 'Edit role'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user == null)
                  TextFormField(
                    initialValue: username,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Username'),
                    onChanged: (value) => username = value,
                    validator: (value) {
                      final username = value?.trim() ?? '';
                      if (username.isEmpty) return 'Enter a username';
                      final alreadyExists = usersList.any(
                        (existingUser) =>
                            (existingUser['username'] ?? '')
                                .trim()
                                .toLowerCase() ==
                            username.toLowerCase(),
                      );
                      if (alreadyExists) return 'Username already exists';
                      return null;
                    },
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'User', child: Text('User')),
                    DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => role = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context, {
                  'username': username.trim(),
                  'role': role,
                  'joinedDate': user?['joinedDate'] ??
                      DateTime.now().toLocal().toString().split(' ').first,
                });
              },
              child: Text(user == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> _addUser() async {
    final user = await _showUserEditor();
    if (user == null) return;
    setState(() => usersList.insert(0, user));
    _showMessage('User added');
  }

  Future<void> _editUser(Map<String, String> user) async {
    final updatedUser = await _showUserEditor(user: user);
    if (updatedUser == null) return;
    if (user['role'] == 'Admin' &&
        updatedUser['role'] == 'User' &&
        usersList.where((entry) => entry['role'] == 'Admin').length == 1) {
      _showMessage('The last administrator cannot be demoted');
      return;
    }
    setState(() {
      user['role'] = updatedUser['role']!;
    });
    _showMessage('User updated');
  }

  Future<void> _deleteUser(Map<String, String> user) async {
    if (user['role'] == 'Admin' &&
        usersList.where((entry) => entry['role'] == 'Admin').length == 1) {
      _showMessage('The last administrator cannot be deleted');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('Remove ${user['username']} from user management?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      setState(() => usersList.remove(user));
      _showMessage('User deleted');
    }
  }

  Future<void> _showRoleFilter() async {
    final role = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Filter users',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final option in ['All', 'Admin', 'User'])
              ListTile(
                title: Text(option),
                trailing: selectedRole == option
                    ? const Icon(Icons.check, color: Color(0xFF0D7A53))
                    : null,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (role != null) setState(() => selectedRole = role);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = usersList.where((u) {
      final matchesSearch = ('${u['username']} ${u['role']}')
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
      final matchesRole = selectedRole == 'All' || u['role'] == selectedRole;
      return matchesSearch && matchesRole;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 12.0,
          ),
          child: Column(
            children: [
              // Header Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                    onPressed: widget.onBackToDashboard,
                  ),
                  const Text(
                    'User Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addUser,
                    icon: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Add User',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D7A53),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Search Bar & Filter Icon
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        hintText: 'Search by username...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.grey.shade200,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.tune_rounded,
                        color: Colors.black87,
                      ),
                      tooltip: 'Filter by role',
                      onPressed: _showRoleFilter,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Username',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Role',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Joined Date',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        'Actions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // User List Table Body
              Expanded(
                child: filteredUsers.isEmpty
                    ? const Center(
                        child: Text('No users found'),
                      )
                    : ListView.separated(
                        itemCount: filteredUsers.length,
                        separatorBuilder: (context, index) {
                          return const Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                          );
                        },
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final isAdmin = user['role'] == 'Admin';

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            color: Colors.white,
                            child: Row(
                              children: [
                                // Username Column
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    user['username'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),

                                // Role Badge Column
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isAdmin
                                            ? const Color(0xFFDBEAFE)
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        user['role'] ?? '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isAdmin
                                              ? const Color(0xFF2563EB)
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Joined Date Column
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    user['joinedDate'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),

                                // Actions Popup Menu Column
                                SizedBox(
                                  width: 40,
                                  child: PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_vert,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        _editUser(user);
                                      } else if (val == 'delete') {
                                        _deleteUser(user);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit Role'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete User'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
