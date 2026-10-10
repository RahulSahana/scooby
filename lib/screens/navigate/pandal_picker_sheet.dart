import 'package:flutter/material.dart';

import '../../data/pandal_data.dart';
import '../../providers/navigation_provider.dart';

class PandalPickerSheet extends StatefulWidget {
  const PandalPickerSheet({
    required this.excludedStopIds,
    required this.maxSelectable,
    super.key,
  });

  final Set<String> excludedStopIds;
  final int maxSelectable;

  @override
  State<PandalPickerSheet> createState() => _PandalPickerSheetState();
}

class _PandalPickerSheetState extends State<PandalPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};

  String _selectedArea = 'All areas';
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleStop(PandalStop stop) {
    setState(() {
      if (_selectedIds.contains(stop.id)) {
        _selectedIds.remove(stop.id);
      } else if (_selectedIds.length < widget.maxSelectable) {
        _selectedIds.add(stop.id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You can add up to ${widget.maxSelectable} more '
                  '${widget.maxSelectable == 1 ? 'stop' : 'stops'}.',
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = pandalCatalog.where((entry) {
      final stop = entry.stop;
      final notAlreadyAdded = !widget.excludedStopIds.contains(stop.id);
      final matchesArea =
          _selectedArea == 'All areas' || entry.area == _selectedArea;

      final query = _searchText.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          stop.name.toLowerCase().contains(query) ||
          entry.area.toLowerCase().contains(query);

      return notAlreadyAdded && matchesArea && matchesSearch;
    }).toList();

    final selectedStops = pandalCatalog
        .where((entry) => _selectedIds.contains(entry.stop.id))
        .map((entry) => entry.stop)
        .toList();

    final screenHeight = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add pandal stops',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchText = value),
              decoration: InputDecoration(
                hintText: 'Search pandals or areas',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchText.isEmpty
                    ? null
                    : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchText = '');
                  },
                  icon: const Icon(Icons.close),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedArea,
              decoration: const InputDecoration(
                labelText: 'Area',
                border: OutlineInputBorder(),
              ),
              items: pandalAreas
                  .map(
                    (area) => DropdownMenuItem(
                  value: area,
                  child: Text(area),
                ),
              )
                  .toList(),
              onChanged: (area) {
                if (area != null) {
                  setState(() => _selectedArea = area);
                }
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: screenHeight * 0.50,
              child: entries.isEmpty
                  ? const Center(child: Text('No pandals found in this area.'))
                  : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final stop = entry.stop;
                  final isSelected = _selectedIds.contains(stop.id);
                  final limitReached =
                      _selectedIds.length >= widget.maxSelectable;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.temple_hindu_outlined),
                    title: Text(stop.name),
                    subtitle: Text(entry.area),
                    trailing: IconButton(
                      tooltip: isSelected ? 'Remove selection' : 'Add stop',
                      onPressed: isSelected || !limitReached
                          ? () => _toggleStop(stop)
                          : null,
                      icon: Icon(
                        isSelected ? Icons.check_circle : Icons.add,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    onTap: isSelected || !limitReached
                        ? () => _toggleStop(stop)
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${selectedStops.length} selected'
                        ' · ${widget.maxSelectable} more available',
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: selectedStops.isEmpty
                      ? null
                      : () => Navigator.pop(context, selectedStops),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}