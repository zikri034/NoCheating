import 'package:flutter/material.dart';
import '../../../core/theme/neo_theme.dart';
import '../../../core/widgets/neo_button.dart';
import '../../../core/widgets/neo_card.dart';
import '../../../core/widgets/neo_text_field.dart';

class StyleGuideScreen extends StatelessWidget {
  const StyleGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NEO-BRUTALIST STYLE GUIDE',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w800,
            color: NeoColors.ink,
          ),
        ),
        backgroundColor: NeoColors.primary,
        foregroundColor: NeoColors.ink,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: NeoColors.ink, width: 3),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('COLOR PALETTE'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildColorSwatch(NeoColors.primary, 'Primary'),
                _buildColorSwatch(NeoColors.secondary, 'Secondary'),
                _buildColorSwatch(NeoColors.tertiary, 'Tertiary'),
                _buildColorSwatch(NeoColors.bg, 'Background'),
                _buildColorSwatch(NeoColors.surface, 'Surface'),
                _buildColorSwatch(NeoColors.ink, 'Ink'),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('COMPONENTS'),
            const SizedBox(height: 16),

            // Demo NeoCard
            const NeoCard(
              header: Text('NEO CARD', style: TextStyle(fontWeight: FontWeight.w800, color: NeoColors.ink)),
              child: Text(
                'This is a Neo-Brutalist card. It has a 3px border and a hard 6px shadow.',
                style: TextStyle(fontFamily: 'Hanken Grotesk', color: NeoColors.ink),
              ),
            ),
            const SizedBox(height: 24),

            // Demo NeoButtons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                NeoButton(text: 'Primary', onPressed: () {}),
                NeoButton(text: 'Secondary', variant: NeoButtonVariant.secondary, onPressed: () {}),
                NeoButton(text: 'Danger', variant: NeoButtonVariant.danger, onPressed: () {}),
              ],
            ),
            const SizedBox(height: 24),

            // Demo NeoTextField
            NeoTextField(
              controller: TextEditingController(),
              label: 'Username',
              hintText: 'Enter your username...',
            ),
            const SizedBox(height: 24),

            NeoButton(
              text: 'Click Me!',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Space Grotesk',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: NeoColors.ink,
      ),
    );
  }

  Widget _buildColorSwatch(Color color, String label) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: NeoColors.ink, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: NeoColors.ink),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
