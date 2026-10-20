import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_widgets.dart';

bool preferenceCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width <= 650;

class PreferenceSection extends StatelessWidget {
  const PreferenceSection(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class PreferenceRow extends StatelessWidget {
  const PreferenceRow({
    super.key,
    required this.label,
    required this.child,
    this.note,
    this.onTap,
    this.fillControl = true,
  });
  final String label;
  final String? note;
  final Widget child;
  final VoidCallback? onTap;
  final bool fillControl;
  @override
  Widget build(BuildContext context) {
    final small = preferenceCompact(context),
        colors = Theme.of(context).colorScheme;
    final row = Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, height: 1.5)),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      note!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: small ? 12 : 24),
          SizedBox(
            width: fillControl ? (small ? 145 : 180) : null,
            child: Semantics(label: label, child: child),
          ),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

class PreferenceSwitch extends StatelessWidget {
  const PreferenceSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.note,
  });
  final String label;
  final String? note;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => PreferenceRow(
    label: label,
    note: note,
    fillControl: false,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    child: SizedBox(
      width: 38,
      height: 26,
      child: FittedBox(
        child: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    ),
  );
}

class PreferenceDropdown<T> extends StatelessWidget {
  const PreferenceDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T>? onChanged;
  @override
  Widget build(BuildContext context) => PreferenceRow(
    label: label,
    child: SizedBox(
      height: preferenceCompact(context) ? 40 : 34,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 14,
          height: 1.3,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        ),
        icon: AppGlyph(
          'chevron-down',
          size: preferenceCompact(context) ? 18 : 14,
        ),
        items: [
          for (final item in items)
            DropdownMenuItem<T>(
              value: item.$1,
              child: Text(
                item.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (value) {
                if (value != null) onChanged!(value);
              },
      ),
    ),
  );
}

class PreferenceSlider extends StatelessWidget {
  const PreferenceSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.output,
    required this.onChanged,
  });
  final String label, output;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => PreferenceRow(
    label: label,
    child: Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              trackShape: const RectangularSliderTrackShape(),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: output,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 46,
          child: Text(
            output,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class PreferenceText extends StatefulWidget {
  const PreferenceText({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.error,
    this.suffix,
    this.obscure = false,
    this.numeric = false,
    this.maxLength,
  });
  final String label, value;
  final String? hint, error;
  final ValueChanged<String> onChanged;
  final Widget? suffix;
  final bool obscure, numeric;
  final int? maxLength;
  @override
  State<PreferenceText> createState() => _PreferenceTextState();
}

class _PreferenceTextState extends State<PreferenceText> {
  late final _controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(PreferenceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PreferenceRow(
        label: widget.label,
        child: SizedBox(
          height: preferenceCompact(context) ? 40 : 34,
          child: TextField(
            controller: _controller,
            obscureText: widget.obscure,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: widget.numeric
                ? TextInputType.number
                : TextInputType.text,
            inputFormatters: [
              if (widget.numeric) FilteringTextInputFormatter.digitsOnly,
              if (widget.maxLength != null)
                LengthLimitingTextInputFormatter(widget.maxLength),
            ],
            style: const TextStyle(fontSize: 14, height: 1.3),
            decoration: InputDecoration(
              hintText: widget.hint,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 6,
              ),
              suffixIcon: widget.suffix,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
            ),
            onChanged: widget.onChanged,
          ),
        ),
      ),
      if (widget.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            widget.error!,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
    ],
  );
}
