Widget _buildTypeView(CommandProfile profile, CommandType type) {
  // Collect all categories that have at least one item of this type
  final validCategories = profile.categories
      .where((c) => c.items.any((i) => i.type == type))
      .toList();

  if (validCategories.isEmpty) {
    return const Center(child: Text("No commands of this type"));
  }

  return ListView.builder(
    padding: const EdgeInsets.all(8),
    itemCount: validCategories.length,
    itemBuilder: (context, index) {
      final cat = validCategories[index];
      final items = cat.items.where((i) => i.type == type).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              cat.name,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          ...items.map((item) => _buildCommandRow(item)),
          const Divider(),
        ],
      );
    },
  );
}
