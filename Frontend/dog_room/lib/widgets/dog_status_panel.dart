import 'package:flutter/material.dart';
import '../models/dog_state.dart';

class DogStatusPanel extends StatelessWidget {
  const DogStatusPanel({super.key, required this.state});
  final DogState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.pets_rounded, color: Color(0xFFB98969), size: 22),
          const SizedBox(width: 8),
          const Text(
            '포메의 방',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF665345),
            ),
          ),
          const Spacer(),
          _Need(
            icon: Icons.restaurant_rounded,
            label: '배부름',
            value: state.hunger,
            color: const Color(0xFFDCA069),
          ),
          _Need(
            icon: Icons.water_drop_rounded,
            label: '청결',
            value: state.cleanliness,
            color: const Color(0xFF80B6C5),
          ),
          _Need(
            icon: Icons.favorite_rounded,
            label: '행복',
            value: state.happiness,
            color: const Color(0xFFD99098),
          ),
          _Need(
            icon: Icons.bedtime_rounded,
            label: '체력',
            value: state.energy,
            color: const Color(0xFFA69CC7),
          ),
        ],
      ),
    );
  }
}

class _Need extends StatelessWidget {
  const _Need({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final description =
        '$label: ${value < 30
            ? '돌봄이 필요해요'
            : value < 60
            ? '괜찮아요'
            : '좋아요'}';
    return Tooltip(
      message: description,
      child: Semantics(
        label: description,
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(height: 5),
              SizedBox(
                width: 22,
                child: LinearProgressIndicator(
                  value: value / 100,
                  minHeight: 3,
                  color: color,
                  backgroundColor: color.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
