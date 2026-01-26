class User {
  final String id;
  final String name;
  final String age;
  final String phone;
  final String email;

  User({
    required this.id,
    required this.name,
    required this.age,
    required this.phone,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'age': age,
    'phone': phone,
    'email': email,
  };

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      age: json['age'] as String,
      phone: json['phone'] as String,
      email: (json['email'] as String?) ?? "",
    );
  }
}
