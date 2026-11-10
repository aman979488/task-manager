import 'package:flutter/material.dart';
import '../models/contact_model.dart';

class ContactAvatar extends StatelessWidget {
  final ContactModel contact;
  final double radius;

  const ContactAvatar({super.key, required this.contact, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    final photo = contact.photo;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFFAB400),
          width: 2.8,
        ),
        color: const Color(0xFF21252B),
      ),
      child: ClipOval(
        child: photo != null
            ? Image.memory(
                photo,
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
              )
            : Center(
                child: _buildAvatarContent(),
              ),
      ),
    );
  }

  Widget _buildAvatarContent() {
    final initial = contact.initial;
    if (initial == '#') {
      return Container(
        width: radius * 0.85,
        height: radius * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        transform: Matrix4.rotationZ(0.785398),
        transformAlignment: Alignment.center,
        child: Center(
          child: Transform.rotate(
            angle: -0.785398,
            child: Text(
              '?',
              style: TextStyle(
                color: const Color(0xFF21252B),
                fontSize: radius * 0.7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
    }
    return Text(
      initial,
      style: TextStyle(
        color: Colors.white,
        fontSize: radius * 0.85,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
