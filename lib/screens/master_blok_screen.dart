import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class MasterBlokScreen extends StatefulWidget {
  const MasterBlokScreen({super.key});

  @override
  State<MasterBlokScreen> createState() => _MasterBlokScreenState();
}

class _MasterBlokScreenState extends State<MasterBlokScreen> {
  List<MasterBlok> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await DatabaseHelper.instance.getMasterBlok();
    if (mounted) setState(() => items = d);
  }

  Future<void> _form({MasterBlok? current}) async {
    final c = TextEditingController(text: current?.kode ?? '');

    final inputOk = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: Text(current == null ? 'Tambah Blok' : 'Edit Blok'),
        content: TextField(
          controller: c,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Kode/Nama Blok'),
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
          'Blok: ${c.text.trim()}\n\n'
          'Simpan data blok ini?',
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
        await DatabaseHelper.instance.addMasterBlok(
          MasterBlok(kode: c.text.trim()),
        );
      } else {
        await DatabaseHelper.instance.updateMasterBlok(
          MasterBlok(id: current.id, kode: c.text.trim()),
        );
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blok sudah ada.')),
        );
      }
    }
  }

  Future<void> _delete(MasterBlok b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Blok?'),
        content: Text(b.kode),
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
    if (ok == true && b.id != null) {
      await DatabaseHelper.instance.deleteMasterBlok(b.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Master Blok')),
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
          final b = items[i];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.location_on_outlined),
              ),
              title: Text(
                b.kode,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _form(current: b);
                  if (v == 'delete') _delete(b);
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
