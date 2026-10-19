import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/dimensions.dart';

enum EqualizerPreset {
  flat('Flat', [0.0, 0.0, 0.0, 0.0, 0.0]),
  bassBoost('Bass Boost', [5.0, 3.5, 1.0, 0.0, -1.0]),
  vocal('Vocal', [-1.5, 2.0, 4.5, 3.0, 1.0]),
  treble('Treble', [-1.0, 0.0, 1.5, 3.5, 5.0]);

  final String label;
  final List<double> gains;
  const EqualizerPreset(this.label, this.gains);
}

class EqualizerSheet extends StatefulWidget {
  const EqualizerSheet({super.key});

  @override
  State<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<EqualizerSheet> {
  static const List<String> _bands = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];
  List<double> _bandValues = [0.0, 0.0, 0.0, 0.0, 0.0];
  EqualizerPreset _selectedPreset = EqualizerPreset.flat;
  bool _volumeNormalization = true;
  bool _gaplessPlayback = true;
  double _crossfadeSeconds = 0.0;

  void _applyPreset(EqualizerPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _bandValues = List<double>.from(preset.gains);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
      ),
      padding: const EdgeInsets.fromLTRB(Dimensions.space20, Dimensions.space12, Dimensions.space20, Dimensions.space24),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Audio Equalizer & Processing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Preset Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: EqualizerPreset.values.map((preset) {
                    final isSelected = _selectedPreset == preset;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(preset.label),
                        selected: isSelected,
                        selectedColor: AppColors.cyanAccent,
                        backgroundColor: AppColors.card,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) => _applyPreset(preset),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              // 5-Band Slider Row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    return Column(
                      children: [
                        Text(
                          '${_bandValues[index] > 0 ? "+" : ""}${_bandValues[index].toStringAsFixed(1)} dB',
                          style: const TextStyle(fontSize: 10, color: AppColors.cyanAccent, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 130,
                          child: RotatedBox(
                            quarterTurns: -1,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                activeTrackColor: AppColors.cyanAccent,
                                inactiveTrackColor: AppColors.surface,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: _bandValues[index],
                                min: -6.0,
                                max: 6.0,
                                onChanged: (val) {
                                  setState(() {
                                    _bandValues[index] = val;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _bands[index],
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              // Volume normalization switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.cyanAccent,
                title: const Text('Volume Normalization (ReplayGain)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                subtitle: const Text('Keeps all songs at consistent volume level', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                value: _volumeNormalization,
                onChanged: (val) => setState(() => _volumeNormalization = val),
              ),
              // Gapless playback switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.cyanAccent,
                title: const Text('Gapless Playback', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                subtitle: const Text('Eliminates pause between consecutive songs', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                value: _gaplessPlayback,
                onChanged: (val) => setState(() => _gaplessPlayback = val),
              ),
              // Crossfade slider
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Crossfade Transitions', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  Text(
                    _crossfadeSeconds == 0 ? 'Off' : '${_crossfadeSeconds.toInt()}s',
                    style: const TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.cyanAccent,
                  inactiveTrackColor: AppColors.card,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: _crossfadeSeconds,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  onChanged: (val) => setState(() => _crossfadeSeconds = val),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
