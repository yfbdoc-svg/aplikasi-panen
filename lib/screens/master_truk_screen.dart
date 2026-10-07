import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class MasterTrukScreen extends StatefulWidget {
  const MasterTrukScreen({super.key});

  @override
  State<MasterTrukScreen> createState() => _MasterTrukScreenState();
}

class _MasterTrukScreenState extends State<MasterTrukScreen> {
  List<MasterTruk> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await DatabaseHelper.instance.getMasterTruk();
    if (mounted) setState(() => items = d);
  }

  Future<void> _form({MasterTruk? current}) async {
    final c = TextEditingController(text: current?.nama ?? '');

    final inputOk = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: Text(current == null ? 'Tambah Truk' : 'Edit Truk'),
        content: TextField(
          controller: c,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Nama Truk'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(x, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(x, true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );

    if (inputOk != true || c.text.trim().isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: const Text('Konfirmasi Simpan'),
        content: Text(
          'Nama Truk: ${c.text.trim()}\n\n'
          'Simpan data truk ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(x, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(x, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (current == null) {
        await DatabaseHelper.instance.addMasterTruk(
          MasterTruk(nama: c.text.trim()),
        );
      } else {
        await DatabaseHelper.instance.updateMasterTruk(
          MasterTruk(id: current.id, nama: c.text.trim()),
        );
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama truk sudah ada.')),
        );
      }
    }
  }

  Future<void> _delete(MasterTruk t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Truk?'),
        content: Text(t.nama),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true && t.id != null) {
      await DatabaseHelper.instance.deleteMasterTruk(t.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Master Truk')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final t = items[i];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.local_shipping_outlined),
              ),
              title: Text(
                t.nama,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _form(current: t);
                  if (v == 'delete') _delete(t);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
