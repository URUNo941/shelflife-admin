import 'package:flutter/material.dart';

// โมเดลข้อมูลผู้ใช้งาน
class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // Admin หรือ Staff
  final String status; // Active หรือ Inactive

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });
}

class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  // โทนสีหลักของระบบ ShelfLife
  final Color primaryGreen = const Color(0xFF0D7A53);
  final Color bgLight = const Color(0xFFF8F9FA);

  // ข้อมูลจำลอง (Mock Data)
  final List<UserModel> users = [
    UserModel(id: '1', name: 'Somchai Jaidee', email: 'somchai@shelflife.com', role: 'Admin', status: 'Active'),
    UserModel(id: '2', name: 'Somsri Raka', email: 'somsri@shelflife.com', role: 'Staff', status: 'Active'),
    UserModel(id: '3', name: 'Anan Sukjai', email: 'anan@shelflife.com', role: 'Staff', status: 'Inactive'),
  ];

  String selectedFilter = 'All';
  String searchQuery = '';

  // Pop-up เพิ่มผู้ใช้งานใหม่
  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String selectedRole = 'Staff';
    String selectedStatus = 'Active';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text(
                'Add New User',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อผู้ใช้งาน (Name)',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'อีเมล (Email)',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'สิทธิ์ (Role)',
                          prefixIcon: Icon(Icons.security),
                          border: OutlineInputBorder(),
                        ),
                        items: ['Admin', 'Staff'].map((role) {
                          return DropdownMenuItem(value: role, child: Text(role));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'สถานะ (Status)',
                          prefixIcon: Icon(Icons.toggle_on_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: ['Active', 'Inactive'].map((status) {
                          return DropdownMenuItem(value: status, child: Text(status));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedStatus = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      setState(() {
                        users.add(
                          UserModel(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            name: nameController.text.trim(),
                            email: emailController.text.trim().isEmpty
                                ? '${nameController.text.trim().toLowerCase().replaceAll(' ', '')}@shelflife.com'
                                : emailController.text.trim(),
                            role: selectedRole,
                            status: selectedStatus,
                          ),
                        );
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // กรองข้อมูลตาม Filter และคำค้นหา Search
    final filteredUsers = users.where((user) {
      final matchesFilter = selectedFilter == 'All' || user.role == selectedFilter;
      final matchesSearch = user.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'User Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // 1. ปุ่ม + Add User (ตามสไตล์แถบเดิม)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add User', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),

          // 2. ช่องค้นหา (Search Bar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by user name or email...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                fillColor: Colors.white,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
              ),
            ),
          ),

          // 3. แถบตัวกรอง (All / Admin / Staff)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFilterChip('All (${users.length})', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('Admin (${users.where((u) => u.role == 'Admin').length})', 'Admin'),
                const SizedBox(width: 8),
                _buildFilterChip('Staff (${users.where((u) => u.role == 'Staff').length})', 'Staff'),
              ],
            ),
          ),

          // 4. รายการแสดงผลผู้ใช้งาน (User List Cards)
          Expanded(
            child: filteredUsers.isEmpty
                ? const Center(child: Text('ไม่พบข้อมูลผู้ใช้งาน', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: primaryGreen.withOpacity(0.1),
                            child: Icon(Icons.person, color: primaryGreen),
                          ),
                          title: Text(
                            user.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text('สิทธิ์: ${user.role}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Chip แสดงสถานะ Active / Inactive
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: user.status == 'Active'
                                      ? Colors.green.withOpacity(0.15)
                                      : Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  user.status,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: user.status == 'Active' ? Colors.green[800] : Colors.grey[700],
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                onSelected: (val) {
                                  if (val == 'delete') {
                                    setState(() => users.removeWhere((u) => u.id == user.id));
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('ลบข้อมูล', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
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

  // Widget ช่วยทำ Filter Chip
  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? primaryGreen : const Color(0xFFE0E0E0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: UserManagementView(),
    ),
  );
}