/// A row of `public.profiles`, created by the database on sign up.
class UserProfile {
  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final String? phone;

  const UserProfile({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.phone,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        email: json['email'] as String?,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        phone: json['phone'] as String?,
      );

  String get name => (displayName != null && displayName!.trim().isNotEmpty)
      ? displayName!.trim()
      : (email?.split('@').first ?? 'Bạn');

  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String firstLetter(String s) => String.fromCharCode(s.runes.first);
    final last = parts.length > 1 ? firstLetter(parts.last) : '';
    return (firstLetter(parts.first) + last).toUpperCase();
  }
}
