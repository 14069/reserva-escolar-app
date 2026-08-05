class SystemAdminModel {
  final int id;
  final String name;
  final String email;
  final String apiToken;
  final String apiTokenExpiresAt;

  const SystemAdminModel({
    required this.id,
    required this.name,
    required this.email,
    required this.apiToken,
    required this.apiTokenExpiresAt,
  });

  factory SystemAdminModel.fromJson(Map<String, dynamic> json) {
    return SystemAdminModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      apiToken: json['api_token'] as String,
      apiTokenExpiresAt: json['api_token_expires_at'] as String,
    );
  }
}
