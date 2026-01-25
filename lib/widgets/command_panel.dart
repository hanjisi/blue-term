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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: SizedBox(
            height: 35,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _globalInputController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '自定义命令',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  height: 35,
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
                      if (_globalInputController.text.isNotEmpty) {
                        widget.onSend(
                          _globalInputController.text,
                          _globalIsHex,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          height: 35,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Text("配置: "),
                    DropdownButton<String>(
                      value: profile?.id,
                      isDense: true,
                      underline: const SizedBox(),
                      items: commandState.profiles
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                p.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(commandProvider.notifier)
                              .setCurrentProfile(val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_note),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: "配置管理",
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CommandEditorPage()),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const SizedBox(
                  height: 35,
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorColor: Colors.blue,
                    unselectedLabelColor: Color(0xFF9E9E9E),
                    labelColor: Colors.blue,
                    labelStyle: TextStyle(fontWeight: FontWeight.normal),
                    tabs: [
                      Tab(text: "简单"),
                      Tab(text: "输入"),
                      Tab(text: "枚举"),
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

  Widget _buildTypeView(CommandProfile? profile, CommandType type) {
    final validCategories = profile?.categories
        .where((c) => c.items.any((i) => i.type == type))
        .toList();

    if (validCategories?.isEmpty ?? true) {
      return const Center(
        child: Text("没有命令", style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      itemCount: validCategories!.length,
      itemBuilder: (context, index) {
        final cat = validCategories[index];
        final items = cat.items.where((i) => i.type == type).toList();

        ///如果是简单命令，使用Wrap布局
        final isSimple = type == CommandType.simple;

        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              backgroundColor: Colors.white,
              collapsedBackgroundColor: Colors.grey.shade50,
              minTileHeight: 20,
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              dense: true,
              visualDensity: VisualDensity.compact,
              title: Row(
                children: [
                  Text(
                    cat.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "(${items.length})",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              childrenPadding: const EdgeInsets.only(
                left: 4,
                right: 4,
                bottom: 4,
              ),
              children: isSimple
                  ? [
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.start,
                          children: items
                              .map((item) => _buildCommandRow(item))
                              .toList(),
                        ),
                      ),
                    ]
                  : items.map((item) => _buildCommandRow(item)).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommandRow(CommandItem item) {
    switch (item.type) {
      case CommandType.simple:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: SizedBox(
            height: 35,
            child: TextButton(
              onPressed: () => widget.onSend(item.data, item.isHex),
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.1),
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Text(item.name),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SizedBox(
        height: 35,
        child: Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 100),
              child: Text(
                widget.item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 35,
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    suffixText: widget.item.unit.isNotEmpty
                        ? widget.item.unit
                        : null,
                    suffixStyle: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 70,
              height: 35,
              child: IconButton(
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.1),
                ),
                icon: const Icon(Icons.send, size: 16, color: Colors.blue),
                onPressed: () => widget.onSend(_ctrl.text, widget.item.isHex),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 100),
            child: Text(
              widget.item.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 35, // Updated height
              child: DropdownButtonFormField<EnumOption>(
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                isExpanded: true,
                value: _selected,
                style: const TextStyle(fontSize: 12, color: Colors.black),
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
            width: 70,
            height: 35, // Updated height
            child: IconButton(
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.1),
              ),
              icon: const Icon(Icons.send, size: 16, color: Colors.blue),
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
