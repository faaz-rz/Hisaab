import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/agency_service.dart';
import '../main.dart';

/// A searchable dropdown for agency codes.
/// When user selects or types a code, onSelected fires with (code, name).
class AgencyCodeDropdown extends StatefulWidget {
  final TextEditingController codeController;
  final TextEditingController nameController;
  final ValueChanged<bool>? onAgencyLocked;
  final String? initialCode;

  const AgencyCodeDropdown({
    super.key,
    required this.codeController,
    required this.nameController,
    this.onAgencyLocked,
    this.initialCode,
  });

  @override
  State<AgencyCodeDropdown> createState() => _AgencyCodeDropdownState();
}

class _AgencyCodeDropdownState extends State<AgencyCodeDropdown> {
  List<Map<String, dynamic>> _agencies = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAgencies();
  }

  Future<void> _loadAgencies() async {
    final agencies = await AgencyService.instance.getAllAgencies();
    if (mounted) setState(() { _agencies = agencies; _loaded = true; });
  }

  void _onSelected(Map<String, dynamic> agency) {
    widget.codeController.text = agency['code'] as String;
    widget.nameController.text = agency['name'] as String;
    widget.onAgencyLocked?.call(true);
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (textEditingValue) {
        if (!_loaded || textEditingValue.text.isEmpty) return _agencies;
        final query = textEditingValue.text.toUpperCase();
        return _agencies.where((a) {
          final code = (a['code'] as String).toUpperCase();
          final name = (a['name'] as String).toUpperCase();
          return code.contains(query) || name.contains(query);
        });
      },
      displayStringForOption: (agency) => agency['code'] as String,
      onSelected: _onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Sync initial value
        if (widget.codeController.text.isNotEmpty && controller.text.isEmpty) {
          controller.text = widget.codeController.text;
        }
        // Keep controllers in sync
        controller.addListener(() {
          if (widget.codeController.text != controller.text) {
            widget.codeController.text = controller.text;
          }
        });

        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Agency Code',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loaded)
                  const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary, size: 24),
              ],
            ),
          ),
          textCapitalization: TextCapitalization.characters,
          onChanged: (val) async {
            widget.codeController.text = val;
            // Also try to auto-fill from registry
            if (val.trim().isNotEmpty) {
              final name = await AgencyService.instance.getNameByCode(val);
              if (name != null) {
                widget.nameController.text = name;
                widget.onAgencyLocked?.call(true);
              } else {
                widget.onAgencyLocked?.call(false);
              }
            } else {
              widget.onAgencyLocked?.call(false);
            }
          },
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            shadowColor: Colors.black26,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (ctx, idx) {
                  final agency = options.elementAt(idx);
                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        agency['code'] as String,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
                      ),
                    ),
                    title: Text(
                      agency['name'] as String,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    ),
                    onTap: () => onSelected(agency),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
