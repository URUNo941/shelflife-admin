// =============================================================================
// UserModel = ข้อมูลบัญชีผู้ใช้ 1 คน
// -----------------------------------------------------------------------------
// - ตรงกับตาราง `users` ในฐานข้อมูล MySQL
// - ใช้ที่หน้า: Login, Register, Profile, User Management (Admin)
// - ไม่มี password อยู่ในโมเดลนี้ เพราะรหัสผ่านต้องเก็บเป็น hash ที่ backend เท่านั้น
//   แอปไม่ควรถือรหัสผ่านไว้ใน object (เหตุผลด้าน security)
// =============================================================================
class UserModel {
  // ค่าคงที่ของ role ประกาศไว้ที่เดียว จะได้ไม่พิมพ์ 'admin' / 'user' ผิดในที่อื่น
  // `static` = เป็นของ class ไม่ใช่ของ object แต่ละตัว เรียกใช้ได้เลย: UserModel.roleAdmin
  static const roleAdmin = 'admin';
  static const roleUser = 'user';

  // ทุก field เป็น `final` = กำหนดค่าได้ครั้งเดียวตอนสร้าง แก้ทีหลังไม่ได้ (immutable)
  // ถ้าอยากเปลี่ยนค่า ต้องสร้าง object ใหม่ด้วย copyWith() (อยู่ด้านล่าง)
  // ข้อดี: ข้อมูลไม่ถูกแก้โดยไม่ตั้งใจจากหลายหน้าจอพร้อมกัน
  final int userId; // คอลัมน์ user_id (Primary Key)
  final String username; // คอลัมน์ username (ห้ามซ้ำ)
  final String email; // อีเมล (ได้มาจากหน้า Register)
  final String role; // 'admin' หรือ 'user' เท่านั้น ตรงกับ enum ใน DB
  final DateTime createdAt; // วันที่สมัคร (คอลัมน์ created_at)

  // Constructor
  // `required` = ต้องส่งค่ามา ถ้าไม่ส่ง compiler แจ้ง error
  // `this.email = ''` = ไม่บังคับ ถ้าไม่ส่งมาจะเป็นค่าว่าง
  // `const` = สร้าง object เป็นค่าคงที่ได้ตอน compile (ประหยัดหน่วยความจำ)
  const UserModel({
    required this.userId,
    required this.username,
    this.email = '',
    required this.role,
    required this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // Getter = ค่าที่ "คำนวณจาก field" ไม่ได้เก็บไว้จริง เรียกใช้เหมือน field: user.isAdmin
  // ---------------------------------------------------------------------------

  // เป็น admin หรือไม่ หน้า Login ใช้ค่านี้เลือกว่าจะพาไปหน้า Admin หรือหน้า User
  bool get isAdmin => role == roleAdmin;

  // ข้อความ role สำหรับแสดงบนหน้าจอ: 'Admin' / 'User' (ตัวแรกพิมพ์ใหญ่)
  // แยกจาก `role` เพราะใน DB เก็บตัวพิมพ์เล็ก แต่บนจออยากให้ดูสวย
  String get roleLabel => isAdmin ? 'Admin' : 'User';

  // วันที่สมัครแบบอ่านง่าย เช่น DateTime(2026, 10, 1) -> 'Oct 1, 2026'
  String get joinedLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    // month ของ DateTime เริ่มที่ 1 แต่ index ของ list เริ่มที่ 0 จึงต้อง -1
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  // แปลงค่า role ที่รับมาให้เป็นรูปแบบมาตรฐานเสมอ
  // เช่น 'Admin', ' ADMIN ' -> 'admin' และค่าอื่นทั้งหมด -> 'user'
  // ทำไมต้องมี: dropdown บนจอส่งค่า 'Admin'/'User' มา แต่ DB ต้องการ 'admin'/'user'
  // และถ้าได้ค่าแปลกๆ มา จะถือเป็น 'user' ไว้ก่อน (ปลอดภัยกว่าการให้สิทธิ์ admin)
  static String normalizeRole(String value) =>
      value.trim().toLowerCase() == roleAdmin ? roleAdmin : roleUser;

  // ---------------------------------------------------------------------------
  // fromJson: แปลง JSON (Map) ที่ได้จาก API -> object UserModel
  // ใช้ตอนต่อ backend: GET /api/users ส่ง JSON กลับมา แล้วแปลงเป็น object ด้วยตัวนี้
  // `factory` = constructor แบบพิเศษที่มี logic ก่อนสร้าง object ได้
  // ชื่อ key ('user_id', 'created_at') ตรงกับชื่อคอลัมน์ใน DB
  // ---------------------------------------------------------------------------
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      // `?? ''` = ถ้าเป็น null ให้ใช้ค่าว่างแทน (API บางตัวอาจไม่ส่ง email มา)
      email: (json['email'] as String?) ?? '',
      role: normalizeRole((json['role'] as String?) ?? roleUser),
      // ถ้าไม่มีวันที่ ใช้เวลาปัจจุบัน ถ้ามี ให้แปลงข้อความ ISO เป็น DateTime
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['created_at'] as String),
    );
  }

  // toJson: แปลง object -> JSON (Map) ใช้ตอนส่งข้อมูลไป API (POST / PUT)
  // ทำงานกลับด้านกับ fromJson (มี unit test ยืนยันว่าแปลงไปแล้วแปลงกลับได้ค่าเดิม)
  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'email': email,
        'role': role,
        'created_at': createdAt.toIso8601String(), // DateTime -> ข้อความมาตรฐาน ISO
      };

  // copyWith: สร้าง object ใหม่ที่ "เหมือนเดิม แต่เปลี่ยนบาง field"
  // เพราะ field เป็น final แก้ตรงๆ ไม่ได้ เช่นตอน Admin เปลี่ยน role:
  //   final promoted = user.copyWith(role: 'Admin');
  // field ที่ไม่ได้ส่งมา (เป็น null) จะใช้ค่าเดิม (`??` = ถ้าเป็น null ใช้ค่าขวา)
  // userId และ createdAt เปลี่ยนไม่ได้ เพราะเป็นตัวตนของ user
  UserModel copyWith({String? username, String? email, String? role}) {
    return UserModel(
      userId: userId,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role == null ? this.role : normalizeRole(role),
      createdAt: createdAt,
    );
  }
}
