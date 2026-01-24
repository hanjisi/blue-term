import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/command_model.dart';
import '../pages/command_editor_page.dart';
import '../providers/command_provider.dart';

class CommandPanel extends ConsumerStatefulWidget {
  final Function(String data, bool isHex) onSend;

  const CommandPanel({super.key, required this.onSend});

  @override
  ConsumerState<CommandPanel> createState() => _CommandPanelState();
}

class _CommandPanelState extends ConsumerState<CommandPanel> {
  final TextEditingController _globalInputController = TextEditingController();
  bool _globalIsHex = false; // Internal state for the manual input box

  @override
  void dispose() {
    _globalInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commandState = ref.watch(commandProvider);
    final profile = commandState.currentProfile;

    if (commandState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (profile == null) {
      return const Center(child: Text("No Profile Selected"));
    }

    // Default category if none

    return Column(
      children: [
        // Global Custom Command Area - Compact
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: SizedBox(
            height: 36, // Explicit height for compactness
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _globalInputController,
                    style: const TextStyle(fontSize: 13), // Smaller text
                    decoration: const InputDecoration(
                      labelText: 'Custom Command',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ), // Compact
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.send, size: 20),
                  onPressed: () {
                    if (_globalInputController.text.isNotEmpty) {
                      widget.onSend(_globalInputController.text, _globalIsHex);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        // Profile Switcher - Compact & Centered with Edit on Right
        Container(
          height: 32, // Fixed height "lower"
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Profile: ", style: TextStyle(fontSize: 12)),
                    DropdownButton<String>(
                      value: profile.id,
                      isDense: true,
                      underline: const SizedBox(), // Clean look
                      iconSize: 20,
                      style: const TextStyle(fontSize: 12, color: Colors.black),
                      items: commandState.profiles
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                p.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null)
                          ref
                              .read(commandProvider.notifier)
                              .setCurrentProfile(val);
                      },
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_note, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: "Manage Profiles",
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CommandEditorPage()),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Categories
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                SizedBox(
                  height: 36, // Compact TabBar
                  child: TabBar(
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    tabs: const [
                      Tab(text: "Simple"),
                      Tab(text: "Input"),
                      Tab(text: "Enum"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTypeView(profile, CommandType.simple),
                      _buildTypeView(profile, CommandType.input),
                      _buildTypeView(profile, CommandType.enumSelect),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeView(CommandProfile profile, CommandType type) {
    final validCategories = profile.categories
        .where((c) => c.items.any((i) => i.type == type))
        .toList();

    if (validCategories.isEmpty) {
      return const Center(
        child: Text("No commands", style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: validCategories.length,
      itemBuilder: (context, index) {
        final cat = validCategories[index];
        final items = cat.items.where((i) => i.type == type).toList();

        // Use Wrap for Simple commands for left-to-right flow
        final isSimple = type == CommandType.simple;

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              cat.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
            tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            childrenPadding: isSimple
                ? const EdgeInsets.all(4)
                : EdgeInsets.zero,
            minTileHeight: 32,
            children: isSimple
                ? [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      children: items
                          .map((item) => _buildCommandRow(item))
                          .toList(),
                    ),
                  ]
                : items.map((item) => _buildCommandRow(item)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCommandRow(CommandItem item) {
    switch (item.type) {
      case CommandType.simple:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
          child: SizedBox(
            height: 36, // Fixed smaller height
            child: ElevatedButton(
              onPressed: () => widget.onSend(item.data, item.isHex),
              style: ElevatedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ), // Squarer
              ),
              child: Text(item.name, style: const TextStyle(fontSize: 13)),
            ),
          ),
        );
      case CommandType.input:
        return _InputCmdRow(item: item, onSend: widget.onSend);
      case CommandType.enumSelect:
        return _EnumCmdRow(item: item, onSend: widget.onSend);
    }
  }
}

class _InputCmdRow extends StatefulWidget {
  final CommandItem item;
  final Function(String, bool) onSend;

  const _InputCmdRow({required this.item, required this.onSend});

  @override
  State<_InputCmdRow> createState() => _InputCmdRowState();
}

class _InputCmdRowState extends State<_InputCmdRow> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.item.data);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70, // Fixed label width
            child: Text(
              widget.item.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 36, // Compact Input
              child: TextField(
                controller: _ctrl,
                scrollPadding: const EdgeInsets.only(
                  bottom: 100,
                ), // Avoid keyboard occlusion
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixText: widget.item.unit.isNotEmpty
                      ? widget.item.unit
                      : null,
                  suffixStyle: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 48,
            height: 36,
            child: IconButton(
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.1),
              ),
              icon: const Icon(Icons.send, size: 18, color: Colors.blue),
              onPressed: () => widget.onSend(_ctrl.text, widget.item.isHex),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnumCmdRow extends StatefulWidget {
  final CommandItem item;
  final Function(String, bool) onSend;

  const _EnumCmdRow({required this.item, required this.onSend});

  @override
  State<_EnumCmdRow> createState() => _EnumCmdRowState();
}

class _EnumCmdRowState extends State<_EnumCmdRow> {
  EnumOption? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.item.enumOptions.isNotEmpty) {
      _selected = widget.item.enumOptions.first;
    }
  }

  @override
  void didUpdateWidget(covariant _EnumCmdRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset if options changed/removed
    if (_selected != null && !widget.item.enumOptions.contains(_selected)) {
      if (widget.item.enumOptions.isNotEmpty) {
        _selected = widget.item.enumOptions.first;
      } else {
        _selected = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              widget.item.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 36,
              child: DropdownButtonFormField<EnumOption>(
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                isExpanded: true,
                value: _selected,
                style: const TextStyle(fontSize: 13, color: Colors.black),
                items: widget.item.enumOptions
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selected = val;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 48,
            height: 36,
            child: IconButton(
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.1),
              ),
              icon: const Icon(Icons.send, size: 18, color: Colors.blue),
              onPressed: () {
                if (_selected != null) {
                  widget.onSend(_selected!.value, widget.item.isHex);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
