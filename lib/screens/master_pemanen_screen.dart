import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class MasterPemanenScreen extends StatefulWidget {
  const MasterPemanenScreen({super.key});

  @override
  State<MasterPemanenScreen> createState() => _MasterPemanenScreenState();
}

class _MasterPemanenScreenState extends State<MasterPemanenScreen> {
  List<Pemanen> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await DatabaseHelper.instance.getPemanen();
    if (mounted) setState(() => items = d);
  }

  Future<void> _form({Pemanen? current}) async {
    final no = TextEditingController(text: current?.no ?? '');
    final nama = TextEditingController(text: current?.nama ?? '');

    final inputOk = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(current == null ? 'Tambah Pemanen' : 'Edit Pemanen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: no,
              decoration: const InputDecoration(labelText: 'No Pemanen'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nama,
              decoration: const InputDecoration(labelText: 'Nama Pemanen'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );

    if (inputOk != true ||
        no.text.trim().isEmpty ||
        nama.text.trim().isEmpty) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Konfirmasi Simpan'),
        content: Text(
          'No Pemanen: ${no.text.trim()}\n'
          'Nama: ${nama.text.trim()}\n\n'
          'Simpan data pemanen ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (current == null) {
        await DatabaseHelper.instance.addPemanen(
          Pemanen(
            no: no.text.trim(),
            nama: nama.text.trim(),
          ),
        );
      } else {
        await DatabaseHelper.instance.updatePemanen(
          Pemanen(
            id: current.id,
            no: no.text.trim(),
            nama: nama.text.trim(),
          ),
        );
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data tidak valid / nomor sudah digunakan.'),
          ),
        );
      }
    }
  }

  Future<void> _delete(Pemanen p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Pemanen?'),
        content: Text('${p.no} - ${p.nama}'),
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

    if (ok == true && p.id != null) {
      await DatabaseHelper.instance.deletePemanen(p.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Pemanen')),
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
          final p = items[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(p.no)),
              title: Text(
                p.nama,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _form(current: p);
                  if (v == 'delete') _delete(p);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Hapus'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
