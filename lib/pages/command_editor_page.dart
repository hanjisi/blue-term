import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/command_model.dart';
import '../providers/command_provider.dart';

class CommandEditorPage extends ConsumerStatefulWidget {
  const CommandEditorPage({super.key});

  @override
  ConsumerState<CommandEditorPage> createState() => _CommandEditorPageState();
}

class _CommandEditorPageState extends ConsumerState<CommandEditorPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Initialize with 0 length, will be fixed in setup
    _tabController = TabController(length: 0, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commandState = ref.watch(commandProvider);
    final profiles = commandState.profiles;
    final currentId = commandState.currentProfileId;

    ref.listen(commandProvider, (prev, next) {
      if (next.profiles.isEmpty) return;
      final idx = next.profiles.indexWhere(
        (p) => p.id == next.currentProfileId,
      );
      if (idx >= 0 &&
          _tabController.length == next.profiles.length &&
          idx != _tabController.index) {
        if (!_tabController.indexIsChanging) {
          _tabController.animateTo(idx);
        }
      }
    });

    if (profiles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Command Editor")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Recreate controller if length changes
    if (_tabController.length != profiles.length) {
      _tabController.dispose();
      int initialIndex = profiles.indexWhere((p) => p.id == currentId);
      if (initialIndex < 0) initialIndex = 0;

      _tabController = TabController(
        length: profiles.length,
        initialIndex: initialIndex,
        vsync: this,
      );
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
          final idx = _tabController.index;
          final currentProfiles = ref.read(commandProvider).profiles;
          if (idx < currentProfiles.length) {
            final p = currentProfiles[idx];
            if (p.id != ref.read(commandProvider).currentProfileId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(commandProvider.notifier).setCurrentProfile(p.id);
              });
            }
          }
        }
        if (mounted) setState(() {});
      });
    }

    final currentProfile = profiles[_tabController.index];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Command Editor"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: profiles.map((p) => Tab(text: p.name)).toList(),
          onTap: (index) {
            ref
                .read(commandProvider.notifier)
                .setCurrentProfile(profiles[index].id);
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'rename')
                _editProfileDetails(currentProfile);
              else if (val == 'add_cat')
                _addCategory(currentProfile);
              else if (val == 'export')
                _exportProfile(currentProfile);
              else if (val == 'delete')
                _deleteProfile(currentProfile);
              else if (val == 'new')
                _createNewProfile();
              else if (val == 'import')
                _importProfile();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rename',
                child: _iconText(
                  Icons.drive_file_rename_outline,
                  "Rename Profile",
                ),
              ),
              PopupMenuItem(
                value: 'add_cat',
                child: _iconText(Icons.create_new_folder, "Add Category"),
              ),
              PopupMenuItem(
                value: 'export',
                child: _iconText(Icons.download, "Export JSON"),
              ),
              PopupMenuItem(
                value: 'delete',
                child: _iconText(
                  Icons.delete,
                  "Delete Profile",
                  color: Colors.red,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'new', child: Text("New Profile")),
              const PopupMenuItem(value: 'import', child: Text("Import JSON")),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: profiles.map((p) => _buildProfileView(p)).toList(),
      ),
    );
  }

  Widget _iconText(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.grey[700], size: 20),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: color)),
      ],
    );
  }

  Widget _buildProfileView(CommandProfile profile) {
    if (profile.categories.isEmpty) {
      return const Center(child: Text("No Categories. Add one via menu (⋮)."));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 20, top: 16),
      children: profile.categories
          .map((cat) => _buildCategoryTile(profile, cat))
          .toList(),
    );
  }

  // Helper method for the bottom sheet menu
  void _showCategoryOptions(CommandProfile p, CommandCategory cat) {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text("Add Command"),
              onTap: () async {
                Navigator.pop(c);
                await _addCommand(p, cat);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Rename Category"),
              onTap: () {
                Navigator.pop(c);
                _renameCategory(p, cat);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                "Delete Category",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(c);
                _deleteCategory(p, cat);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(CommandProfile profile, CommandCategory cat) {
    // Customizing ExpansionTile to have leading triangle and trailing menu
    // We use standard ExpansionTile but with controlAffinity: ListTileControlAffinity.leading
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          cat.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_horiz), // Three dots
          onPressed: () => _showCategoryOptions(profile, cat),
        ),
        children: cat.items
            .map(
              (item) => ListTile(
                title: Text(item.name),
                subtitle: Text(
                  "${item.type.name} ${item.unit.isNotEmpty ? '(${item.unit})' : ''}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showCommandOptions(profile, cat, item),
                ),
                onTap: () => _editCommand(profile, cat, item),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showCommandOptions(
    CommandProfile p,
    CommandCategory cat,
    CommandItem item,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Edit Command"),
              onTap: () {
                Navigator.pop(c);
                _editCommand(p, cat, item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                "Delete Command",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(c);
                _deleteCommand(p, cat, item);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Actions ---

  // --- Actions ---

  Future<void> _createNewProfile() async {
    final p = CommandProfile(name: "New Profile", categories: []);
    await ref.read(commandProvider.notifier).saveProfile(p);
    ref.read(commandProvider.notifier).setCurrentProfile(p.id);
  }

  Future<void> _deleteProfile(CommandProfile p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Profile"),
        content: Text("Are you sure you want to delete ${p.name}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(commandProvider.notifier).deleteProfile(p.id);
    }
  }

  Future<void> _importProfile() async {
    await showDialog(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text("Import Profile"),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(c);
              _importFromJson();
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Paste JSON"),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(c);
              _importFromUrl();
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Download from URL"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromJson() async {
    final text = await showDialog<String>(
      context: context,
      builder: (c) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text("Paste JSON"),
          content: TextField(
            controller: ctrl,
            maxLines: 10,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: "{ ... }",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text("Import"),
            ),
          ],
        );
      },
    );
    if (text != null && text.isNotEmpty) {
      _processImport(text);
    }
  }

  Future<void> _importFromUrl() async {
    final url = await _promptText("Enter URL");
    if (url != null && url.isNotEmpty) {
      try {
        // Use standard HttpClient to avoid conflicts if 'http' package behaves oddly or for lightness
        final request = await HttpClient().getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode == 200) {
          final jsonString = await response.transform(utf8.decoder).join();
          _processImport(jsonString);
        } else {
          throw "HTTP ${response.statusCode}";
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Download Error: $e")));
        }
      }
    }
  }

  Future<void> _processImport(String jsonString) async {
    try {
      await ref.read(commandProvider.notifier).importProfile(jsonString);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Imported successfully")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _exportProfile(CommandProfile p) {
    final json = jsonEncode(p.toJson());
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("JSON copied to clipboard")));
  }

  Future<void> _editProfileDetails(CommandProfile p) async {
    final name = await _promptText("Rename Profile", initial: p.name);
    if (name != null && name.isNotEmpty) {
      _saveProfileWithMap(p, (map) {
        map['name'] = name;
      });
    }
  }

  Future<void> _addCategory(CommandProfile p) async {
    final name = await _promptText("Category Name");
    if (name != null) {
      final newCat = CommandCategory(name: name, items: []);
      _saveProfileWithMap(p, (map) {
        final cats = (map['categories'] as List).cast<Map<String, dynamic>>();
        cats.add(newCat.toJson());
        map['categories'] = cats;
      });
    }
  }

  Future<void> _renameCategory(CommandProfile p, CommandCategory cat) async {
    final name = await _promptText("Rename Category", initial: cat.name);
    if (name != null && name.isNotEmpty) {
      _updateCategoryInMap(p, cat.id, (cMap) {
        cMap['name'] = name;
      });
    }
  }

  Future<void> _deleteCategory(CommandProfile p, CommandCategory c) async {
    _saveProfileWithMap(p, (map) {
      final cats = (map['categories'] as List).cast<Map<String, dynamic>>();
      cats.removeWhere((x) => x['id'] == c.id);
      map['categories'] = cats;
    });
  }

  Future<void> _addCommand(CommandProfile p, CommandCategory cat) async {
    final newItem = await _showCommandDialog();
    if (newItem != null) {
      _updateCategoryInMap(p, cat.id, (cMap) {
        final items = (cMap['items'] as List).cast<Map<String, dynamic>>();
        items.add(newItem.toJson());
        cMap['items'] = items;
      });
    }
  }

  Future<void> _editCommand(
    CommandProfile p,
    CommandCategory cat,
    CommandItem item,
  ) async {
    final updatedItem = await _showCommandDialog(initialItem: item);
    if (updatedItem != null) {
      _updateCategoryInMap(p, cat.id, (cMap) {
        final items = (cMap['items'] as List).cast<Map<String, dynamic>>();
        final idx = items.indexWhere((x) => x['id'] == item.id);
        if (idx != -1) {
          items[idx] = updatedItem.toJson();
          cMap['items'] = items;
        }
      });
    }
  }

  Future<void> _deleteCommand(
    CommandProfile p,
    CommandCategory cat,
    CommandItem item,
  ) async {
    _updateCategoryInMap(p, cat.id, (cMap) {
      final items = (cMap['items'] as List).cast<Map<String, dynamic>>();
      items.removeWhere((x) => x['id'] == item.id);
      cMap['items'] = items;
    });
  }

  Future<CommandItem?> _showCommandDialog({CommandItem? initialItem}) {
    return showDialog<CommandItem>(
      context: context,
      builder: (context) => _CommandDialog(initialItem: initialItem),
    );
  }

  // --- Helpers ---

  Future<String?> _promptText(String label, {String? initial}) {
    return showDialog<String>(
      context: context,
      builder: (c) {
        final ctrl = TextEditingController(text: initial);
        return AlertDialog(
          title: Text(label),
          content: TextField(controller: ctrl),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // Safe update by going through JSON to ensure new instance creation (Immutability pattern)
  Future<void> _saveProfileWithMap(
    CommandProfile p,
    Function(Map<String, dynamic>) modifier,
  ) async {
    final map = p.toJson();
    modifier(map); // Mutate the map
    final newP = CommandProfile.fromJson(map);
    await ref.read(commandProvider.notifier).saveProfile(newP);
  }

  Future<void> _updateCategoryInMap(
    CommandProfile p,
    String catId,
    Function(Map<String, dynamic>) catModifier,
  ) async {
    _saveProfileWithMap(p, (map) {
      final cats = (map['categories'] as List).cast<Map<String, dynamic>>();
      final idx = cats.indexWhere((c) => c['id'] == catId);
      if (idx != -1) {
        catModifier(cats[idx]);
        map['categories'] = cats;
      }
    });
  }
}

class _CommandDialog extends StatefulWidget {
  final CommandItem? initialItem;

  const _CommandDialog({this.initialItem});

  @override
  State<_CommandDialog> createState() => _CommandDialogState();
}

class _CommandDialogState extends State<_CommandDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _dataCtrl;
  late TextEditingController _unitCtrl; // New Unit Controller
  late CommandType _type;
  late bool _isHex;
  late List<EnumOption> _enumOptions; // Use EnumOption model

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _dataCtrl = TextEditingController(text: item?.data ?? '');
    _unitCtrl = TextEditingController(text: item?.unit ?? '');
    _type = item?.type ?? CommandType.simple;
    _isHex = item?.isHex ?? false;
    _enumOptions = List.from(item?.enumOptions ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dataCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialItem == null ? "New Command" : "Edit Command"),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: "Name"),
                  validator: (v) =>
                      v == null || v.isEmpty ? "Name required" : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CommandType>(
                  value: _type,
                  decoration: const InputDecoration(labelText: "Type"),
                  items: CommandType.values
                      .map(
                        (e) => DropdownMenuItem(value: e, child: Text(e.name)),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _type = val);
                  },
                ),
                const SizedBox(height: 16),

                // Fields based on Type
                if (_type == CommandType.input) ...[
                  TextFormField(
                    controller: _unitCtrl,
                    decoration: const InputDecoration(
                      labelText: "Unit (e.g. ms, V)",
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 16),
                ],

                if (_type != CommandType.enumSelect) ...[
                  TextFormField(
                    controller: _dataCtrl,
                    decoration: const InputDecoration(
                      labelText: "Data / Default Value",
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text("Hex Mode"),
                    value: _isHex,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _isHex = v ?? false),
                  ),
                ] else ...[
                  // Enum Options Editor
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Options (Name : Value)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._enumOptions.asMap().entries.map((entry) {
                    final opt = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(child: Text("${opt.name} : ${opt.value}")),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 16,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() {
                                _enumOptions.removeAt(entry.key);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Add Option"),
                    onPressed: _addEnumOption,
                  ),
                  CheckboxListTile(
                    title: const Text("Send as Hex"),
                    value: _isHex,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _isHex = v ?? false),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(onPressed: _save, child: const Text("Save")),
      ],
    );
  }

  Future<void> _addEnumOption() async {
    // Need custom dialog for Name + Value
    final result = await showDialog<EnumOption>(
      context: context,
      builder: (c) {
        final nameCtrl = TextEditingController();
        final valCtrl = TextEditingController();
        return AlertDialog(
          title: const Text("Add Option"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Name (Display)"),
              ),
              TextField(
                controller: valCtrl,
                decoration: const InputDecoration(labelText: "Value (Send)"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && valCtrl.text.isNotEmpty) {
                  Navigator.pop(
                    c,
                    EnumOption(name: nameCtrl.text, value: valCtrl.text),
                  );
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
    if (result != null) {
      setState(() {
        _enumOptions.add(result);
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final newItem = CommandItem(
        id: widget.initialItem?.id, // Keep ID if editing
        name: _nameCtrl.text,
        type: _type,
        data: _dataCtrl.text,
        unit: _unitCtrl.text,
        enumOptions: _enumOptions,
        isHex: _isHex,
      );
      Navigator.pop(context, newItem);
    }
  }
}
