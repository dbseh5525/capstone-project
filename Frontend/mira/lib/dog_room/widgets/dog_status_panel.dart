import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/dog_state.dart';

class DogStatusPanel extends StatelessWidget {
  const DogStatusPanel({super.key, required this.state});
  final DogState state;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(CupertinoIcons.paw, color: Color(0xFF315E50), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '보리의 방',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              'Lv.${state.level} · ${state.stage.label}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF68766D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Need('배부름', state.hunger, const Color(0xFFB8874D)),
            const SizedBox(width: 12),
            _Need('청결', state.cleanliness, const Color(0xFF5E92A0)),
            const SizedBox(width: 12),
            _Need('행복', state.happiness, const Color(0xFFBF7779)),
            const SizedBox(width: 12),
            _Need('체력', state.energy, const Color(0xFF8B82AC)),
          ],
        ),
      ],
    ),
  );
}

class _Need extends StatelessWidget {
  const _Need(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: '$label $value퍼센트, ${value < 30 ? '돌봄이 필요해요' : '좋아요'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF68766D)),
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: value / 100,
            minHeight: 5,
            color: color,
            backgroundColor: color.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    ),
  );
}
