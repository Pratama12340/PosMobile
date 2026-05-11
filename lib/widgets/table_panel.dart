import 'package:flutter/material.dart';
import '../constants/style.dart';
import '../services/api_service.dart';

class TablePanel extends StatefulWidget {
  final int? currentTableId;
  final Function(Map<String, dynamic>) onTableSelected;
  final VoidCallback onClose;

  const TablePanel({
    super.key,
    required this.currentTableId,
    required this.onTableSelected,
    required this.onClose,
  });

  @override
  State<TablePanel> createState() => _TablePanelState();
}

class _TablePanelState extends State<TablePanel> {
  bool _isLoading = true;
  List<dynamic> _availableTables = [];

  @override
  void initState() {
    super.initState();
    _loadTablesFromApi();
  }

  Future<void> _loadTablesFromApi() async {
    try {
      final tables = await ApiService.getTables();

      tables.sort((a, b) {
        String nameA = (a['name'] ?? '').toString();
        String nameB = (b['name'] ?? '').toString();

        int? numA = int.tryParse(nameA.replaceAll(RegExp(r'[^0-9]'), ''));
        int? numB = int.tryParse(nameB.replaceAll(RegExp(r'[^0-9]'), ''));

        if (numA != null && numB != null && numA != numB) {
          return numA.compareTo(numB);
        }
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _availableTables = tables;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> indoorTables = [];
    List<dynamic> outdoorTables = [];
    List<dynamic> otherTables = [];

    for (var table in _availableTables) {
      String name = (table['name'] ?? '').toString().toLowerCase();
      if (name.contains('indor') || name.contains('indoor')) {
        indoorTables.add(table);
      } else if (name.contains('outdor') || name.contains('outdoor')) {
        outdoorTables.add(table);
      } else {
        otherTables.add(table);
      }
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppStyle.primaryBlue,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (indoorTables.isNotEmpty) ...[
                        _buildSectionTitle("Indoor Area"),
                        _buildTableGrid(indoorTables),
                        const SizedBox(height: 25),
                      ],
                      if (outdoorTables.isNotEmpty) ...[
                        _buildSectionTitle("Outdoor Area"),
                        _buildTableGrid(outdoorTables),
                        const SizedBox(height: 25),
                      ],
                      if (otherTables.isNotEmpty) ...[
                        _buildSectionTitle("Daftar Meja"),
                        _buildTableGrid(otherTables),
                        const SizedBox(height: 25),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableGrid(List<dynamic> tables) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double spacing = 12;
        double itemWidth = ((constraints.maxWidth - (spacing * 2)) / 3) - 0.1;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: tables.map((t) => _buildDynamicCard(t, itemWidth)).toList(),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Pilih Meja / Area",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'Poppins',
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black54,
          fontSize: 13,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildDynamicCard(dynamic table, double width) {
    int id = table['id'] ?? 0;
    String name = table['name']?.toString() ?? '-';
    String cap = table['capacity']?.toString() ?? '0';

    return _buildTableCard(
      title: name,
      capacity: cap,
      isSelected: widget.currentTableId == id,
      onTap: () => widget.onTableSelected({
        'id': id,
        'name': name,
        'capacity': int.tryParse(cap) ?? 0,
      }),
      width: width,
    );
  }

  Widget _buildTableCard({
    required String title,
    required String capacity,
    required bool isSelected,
    required VoidCallback onTap,
    required double width,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppStyle.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppStyle.primaryBlue : Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.person,
                  size: 15,
                  color: isSelected ? Colors.white70 : Colors.black45,
                ),
                const SizedBox(width: 4),
                Text(
                  capacity,
                  style: TextStyle(
                    color: isSelected ? Colors.white70 : Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
