import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../user/login_view.dart';
import '../user/user_data.dart';

class ApiAdminView extends StatefulWidget {
  final String kind;
  final VoidCallback? onBack;
  const ApiAdminView({super.key, required this.kind, this.onBack});
  @override
  State<ApiAdminView> createState() => _ApiAdminViewState();
}

class _ApiAdminViewState extends State<ApiAdminView> {
  late Future<dynamic> _data;
  String _search = '';
  DateTime? _from, _to;
  bool _saving = false;
  bool get _products => widget.kind == 'products';
  bool get _users => widget.kind == 'users';
  bool get _summary => !_products && !_users;
  String get _path => _summary
      ? '/admin/analytics/summary${_from == null ? '' : '?from=${_date(_from!)}&to=${_date(_to!)}'}'
      : '/admin/${widget.kind}';
  String _date(DateTime d) => d.toIso8601String().substring(0, 10);
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _data = ApiClient.instance.request('GET', _path));
  }

  void _error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final names = _products
        ? ['barcode', 'product_name', 'category']
        : ['username', if (row == null) 'password'];
    final controls = {
      for (final name in names)
        name: TextEditingController(text: row?[name]?.toString() ?? '')
    };
    var role = row?['role'] ?? 'user';
    final form = GlobalKey<FormState>();
    final values = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, change) => AlertDialog(
                  title: Text(
                      '${row == null ? 'Add' : 'Edit'} ${_products ? 'product' : 'user'}'),
                  content: SingleChildScrollView(
                      child: Form(
                          key: form,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            for (final name in names)
                              TextFormField(
                                  controller: controls[name],
                                  obscureText: name == 'password',
                                  decoration: InputDecoration(
                                      labelText: name.replaceAll('_', ' ')),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Required'
                                          : name == 'password' && v.length < 8
                                              ? 'At least 8 characters'
                                              : null),
                            if (_users)
                              DropdownButtonFormField<String>(
                                  initialValue: role,
                                  items: ['user', 'admin']
                                      .map((r) => DropdownMenuItem(
                                          value: r, child: Text(r)))
                                      .toList(),
                                  onChanged: (r) => change(() => role = r!)),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          if (form.currentState!.validate()) {
                            Navigator.pop(ctx, {
                              for (final n in names) n: controls[n]!.text,
                              if (_users) 'role': role
                            });
                          }
                        },
                        child: const Text('Save'))
                  ],
                )));
    // Controllers stay alive until the dialog's closing animation is finished.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final c in controls.values) {
      c.dispose();
    }
    if (values == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ApiClient.instance.request(
          row == null ? 'POST' : 'PATCH',
          row == null
              ? _path
              : '$_path/${row[_products ? 'product_id' : 'user_id']}',
          values);
      if (mounted) _reload();
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Deactivate record?'),
                content: const Text(
                    'Existing inventory and history will be preserved.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Deactivate'))
                ]));
    if (yes != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ApiClient.instance.request(
          'DELETE', '$_path/${row[_products ? 'product_id' : 'user_id']}');
      if (mounted) _reload();
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _range() async {
    final range = await showDateRangePicker(
        context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (range != null && mounted) {
      _from = range.start;
      _to = range.end;
      _reload();
    }
  }

  void _logout() {
    ApiClient.instance.logout();
    UserInventory.instance.clear();
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginView()), (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(_products
                ? 'Master Catalog'
                : _users
                    ? 'User Management'
                    : widget.kind == 'dashboard'
                        ? 'Dashboard'
                        : 'System Analytics'),
            leading: widget.onBack == null
                ? null
                : IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back)),
            actions: [
              IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh'),
              IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  tooltip: 'Log out')
            ]),
        floatingActionButton: _summary
            ? null
            : FloatingActionButton(
                onPressed: _saving ? null : () => _edit(),
                child: const Icon(Icons.add)),
        body: Column(children: [
          if (_saving) const LinearProgressIndicator(),
          if (!_summary)
            Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                    decoration: const InputDecoration(
                        labelText: 'Search', prefixIcon: Icon(Icons.search)),
                    onChanged: (s) =>
                        setState(() => _search = s.toLowerCase()))),
          if (widget.kind == 'analytics')
            TextButton(
                onPressed: _range,
                child: Text(_from == null
                    ? 'Filter events by date'
                    : '${_date(_from!)} – ${_date(_to!)}')),
          Expanded(
              child: FutureBuilder<dynamic>(
                  future: _data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${snapshot.error}'),
                        TextButton(
                            onPressed: _reload, child: const Text('Retry'))
                      ]));
                    }
                    if (_summary) {
                      final d = snapshot.data as Map<String, dynamic>;
                      final events = d['events'] as List;
                      return ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            for (final key in [
                              'total_users',
                              'total_products',
                              'active_items',
                              'expiring_soon'
                            ])
                              Card(
                                  child: ListTile(
                                      title: Text(key.replaceAll('_', ' ')),
                                      trailing: Text('${d[key]}',
                                          style:
                                              const TextStyle(fontSize: 24)))),
                            const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                    'Inventory events (recorded since V2)')),
                            if (events.isEmpty)
                              const ListTile(
                                  title: Text('No events in this period.')),
                            for (final e in events)
                              ListTile(
                                  title: Text('${e['event_type']}'),
                                  subtitle: Text(
                                      'Quantity change: ${e['quantity_change']}'),
                                  trailing: Text('${e['event_count']} events')),
                          ]);
                    }
                    final rows = (snapshot.data as List)
                        .cast<Map<String, dynamic>>()
                        .where((r) =>
                            r.values.join(' ').toLowerCase().contains(_search))
                        .toList();
                    if (rows.isEmpty) {
                      return const Center(child: Text('No records found.'));
                    }
                    return ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final row = rows[i];
                          return ListTile(
                              title: Text(
                                  '${row[_products ? 'product_name' : 'username']}'),
                              subtitle: Text(_products
                                  ? '${row['barcode']} • ${row['category']}'
                                  : '${row['role']} • ${row['is_active'] == 1 ? 'Active' : 'Inactive'}'),
                              onTap: _saving ? null : () => _edit(row),
                              trailing: IconButton(
                                  onPressed:
                                      _saving ? null : () => _remove(row),
                                  icon: const Icon(Icons.block)));
                        });
                  })),
        ]),
      );
}
