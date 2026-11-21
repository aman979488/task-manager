class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.contactNo,
    required this.photoUrl,
    this.role = 'user',
  });

  final String uid;
  final String name;
  final String email;
  final String contactNo;
  final String? photoUrl;
  final String role;

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'email': email,
    'contactNo': contactNo,
    'photoUrl': photoUrl,
    'role': role,
  };
}
