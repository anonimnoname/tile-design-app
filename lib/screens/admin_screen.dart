import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/tile_model.dart';
import '../database/db_helper.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<DesignTile> tiles = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTiles();
  }

  Future<void> _loadTiles() async {
    setState(() => isLoading = true);
    tiles = await DesignDbHelper.instance.getAllTiles();
    setState(() => isLoading = false);
  }

  void _showTileDialog({DesignTile? existingTile}) {
    final isEditing = existingTile != null;

    final nameController =
        TextEditingController(text: isEditing ? existingTile.name : '');
    final widthController = TextEditingController(
        text: isEditing ? existingTile.widthCm.toString() : '');
    final heightController = TextEditingController(
        text: isEditing ? existingTile.heightCm.toString() : '');
    final priceController = TextEditingController(
        text: isEditing
            ? existingTile.pricePerSquareMeter.toStringAsFixed(0)
            : '');

    String? selectedImagePath = isEditing && existingTile.imagePath.isNotEmpty
        ? existingTile.imagePath
        : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title:
                  Text(isEditing ? 'Редактировать кафель' : 'Добавить кафель'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                            labelText: 'Название кафеля')),
                    TextField(
                        controller: widthController,
                        decoration:
                            const InputDecoration(labelText: 'Ширина (см)'),
                        keyboardType: TextInputType.number),
                    TextField(
                        controller: heightController,
                        decoration:
                            const InputDecoration(labelText: 'Длина (см)'),
                        keyboardType: TextInputType.number),
                    TextField(
                        controller: priceController,
                        decoration: const InputDecoration(
                            labelText: 'Цена за 1 кв.м (сум)'),
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            FilePickerResult? result = await FilePicker.platform
                                .pickFiles(type: FileType.image);
                            if (result != null) {
                              setStateDialog(() {
                                selectedImagePath = result.files.single.path;
                              });
                            }
                          },
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Выбрать фото'),
                        ),
                        const SizedBox(width: 15),
                        if (selectedImagePath != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(selectedImagePath!),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              // --- ЗАЩИТА ОТ ОШИБОК ---
                              // Если Мак заблокирует файл, вместо красного текста будет аккуратная иконка
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.red.shade50,
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.red),
                                );
                              },
                            ),
                          )
                        else
                          const Text('Фото не выбрано',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена')),
                ElevatedButton(
                  onPressed: () async {
                    final updatedTile = DesignTile(
                      id: isEditing ? existingTile.id : null,
                      name: nameController.text,
                      widthCm: double.tryParse(widthController.text) ?? 0,
                      heightCm: double.tryParse(heightController.text) ?? 0,
                      pricePerSquareMeter:
                          double.tryParse(priceController.text) ?? 0,
                      imagePath: selectedImagePath ?? '',
                    );

                    if (isEditing) {
                      await DesignDbHelper.instance.updateTile(updatedTile);
                    } else {
                      await DesignDbHelper.instance.insertTile(updatedTile);
                    }

                    _loadTiles();
                    if (mounted) Navigator.pop(context);
                  },
                  child: Text(isEditing ? 'Обновить' : 'Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель: Каталог'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : tiles.isEmpty
              ? const Center(
                  child:
                      Text('Каталог пуст. Нажмите +, чтобы добавить кафель.'))
              : ListView.builder(
                  itemCount: tiles.length,
                  itemBuilder: (context, index) {
                    final tile = tiles[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: tile.imagePath.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(tile.imagePath),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    // Защита для списка товаров
                                    errorBuilder: (c, o, s) => const Icon(
                                        Icons.broken_image,
                                        size: 40,
                                        color: Colors.grey)),
                              )
                            : const Icon(Icons.grid_view,
                                size: 40, color: Colors.blueGrey),
                        title: Text(tile.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'Размер: ${tile.widthCm}x${tile.heightCm} см\nЦена: ${tile.pricePerSquareMeter.toSpaceSeparated()} сум / кв.м'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.blueAccent),
                              onPressed: () =>
                                  _showTileDialog(existingTile: tile),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await DesignDbHelper.instance
                                    .deleteTile(tile.id!);
                                _loadTiles();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTileDialog(),
        backgroundColor: Colors.blueGrey,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
