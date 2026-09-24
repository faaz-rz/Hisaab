import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/account_service.dart';

class ProfileAvatar extends StatelessWidget {
  final LocalProfile profile;
  final double size;
  const ProfileAvatar({super.key, required this.profile, this.size = 64});
  static const colors = [
    Color(0xFF348F97),
    Color(0xFF7763BE),
    Color(0xFFB57545),
    Color(0xFF4D7EA7),
    Color(0xFFAA5974)
  ];
  @override
  Widget build(BuildContext context) {
    final color = colors[
        profile.id.codeUnits.fold<int>(0, (a, b) => a + b) % colors.length];
    Uint8List? photo;
    try {
      if (profile.photoBase64 != null) {
        photo = base64Decode(profile.photoBase64!);
      }
    } catch (_) {/* Safe initials fallback. */}
    final initials = profile.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s.characters.first.toUpperCase())
        .join();
    final fallback = Center(
        child: Text(initials.isEmpty ? 'H' : initials,
            style: TextStyle(
                fontSize: size * .31,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 2)));
    return Semantics(
        image: true,
        label: '${profile.name} profile picture',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * .23),
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    Color.lerp(color, const Color(0xFF102433), .45)!
                  ])),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(size * .23),
              child: photo == null
                  ? fallback
                  : Image.memory(photo,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => fallback)),
        ));
  }
}
