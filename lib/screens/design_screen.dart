import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../models/tile_model.dart';
import '../database/db_helper.dart';

class DesignScreen extends StatefulWidget {
  const DesignScreen({super.key});

  @override
  State<DesignScreen> createState() => _DesignScreenState();
}

class _DesignScreenState extends State<DesignScreen> {
  String roomType = 'toilet';

  final lengthController = TextEditingController(text: '3.0');
  final widthController = TextEditingController(text: '2.0');
  final heightController = TextEditingController(text: '2.5');

  List<DesignTile> catalogTiles = [];
  bool isLoading = true;
  bool addReserve = false;

  int currentViewWall = 1;

  DesignTile? wall1Tile;
  DesignTile? wall2Tile;
  DesignTile? wall3Tile;
  DesignTile? wall4Tile;
  DesignTile? floorTile;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final tiles = await DesignDbHelper.instance.getAllTiles();
    setState(() {
      catalogTiles = tiles;
      isLoading = false;
    });
  }

  Map<String, dynamic> _calculateResults() {
    double length = double.tryParse(lengthController.text) ?? 0.0;
    double width = double.tryParse(widthController.text) ?? 0.0;
    double height = double.tryParse(heightController.text) ?? 0.0;

    if (length <= 0 || width <= 0 || height <= 0) return {};

    Map<int, int> tilePieces = {};
    Map<int, DesignTile> tileObjects = {};

    void addSurface(DesignTile? tile, double surfaceWidth, double surfaceHeight,
        {bool hasDoor = false}) {
      if (tile == null || surfaceWidth <= 0 || surfaceHeight <= 0) return;

      double tileWidthM = tile.widthCm / 100;
      double tileHeightM = tile.heightCm / 100;
      if (tileWidthM <= 0 || tileHeightM <= 0) return;

      int fullColumns = (surfaceWidth / tileWidthM).floor();
      double fraction = (surfaceWidth / tileWidthM) - fullColumns;
      int rows = (surfaceHeight / tileHeightM).ceil();

      int extraTiles = 0;
      if (fraction > 0.5) {
        extraTiles = rows;
      } else if (fraction > 0) {
        extraTiles = (rows / 2).ceil();
      }

      int piecesForSurface = (fullColumns * rows) + extraTiles;

      if (hasDoor) {
        int doorCols = (0.8 / tileWidthM).floor();
        int doorRows = (2.10 / tileHeightM).floor();
        int piecesToSubtract = doorCols * doorRows;

        piecesForSurface -= piecesToSubtract;
        if (piecesForSurface < 0) piecesForSurface = 0;
      }

      tilePieces[tile.id!] = (tilePieces[tile.id!] ?? 0) + piecesForSurface;
      tileObjects[tile.id!] = tile;
    }

    addSurface(wall1Tile, length, height);
    addSurface(wall2Tile, width, height);
    addSurface(wall3Tile, length, height, hasDoor: true);
    addSurface(wall4Tile, width, height);
    addSurface(floorTile, length, width);

    List<Map<String, dynamic>> itemsSummary = [];
    double grandTotalSum = 0;

    tilePieces.forEach((tileId, basePieces) {
      final tile = tileObjects[tileId]!;
      int totalPieces = basePieces;

      if (addReserve) {
        int reservePieces = (basePieces * 0.05).ceil();
        if (reservePieces == 0) reservePieces = 1;
        totalPieces += reservePieces;
      }

      double tileAreaSqM = (tile.widthCm / 100) * (tile.heightCm / 100);
      double finalArea = totalPieces * tileAreaSqM;
      double totalCost = finalArea * tile.pricePerSquareMeter;
      grandTotalSum += totalCost;

      itemsSummary.add({
        'name':
            '${tile.name} (${tile.widthCm.toStringAsFixed(0)}x${tile.heightCm.toStringAsFixed(0)} см)',
        'totalPieces': totalPieces,
        'finalArea': finalArea,
        'cost': totalCost,
      });
    });

    return {'items': itemsSummary, 'grandTotal': grandTotalSum};
  }

  Widget _buildTileSearchField(
      String label, DesignTile? selectedTile, Function(DesignTile?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: Autocomplete<DesignTile>(
              displayStringForOption: (DesignTile option) =>
                  '${option.name} — ${option.widthCm.toStringAsFixed(0)}x${option.heightCm.toStringAsFixed(0)} см (${option.pricePerSquareMeter.toSpaceSeparated()} сум/м²)',
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return catalogTiles;
                }
                return catalogTiles.where((tile) {
                  return tile.name
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()) ||
                      '${tile.widthCm}x${tile.heightCm}'
                          .contains(textEditingValue.text);
                });
              },
              onSelected: (DesignTile selection) {
                onChanged(selection);
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                if (selectedTile != null && controller.text.isEmpty) {
                  controller.text =
                      '${selectedTile.name} — ${selectedTile.widthCm.toStringAsFixed(0)}x${selectedTile.heightCm.toStringAsFixed(0)} см (${selectedTile.pricePerSquareMeter.toSpaceSeparated()} сум/м²)';
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Введите название или размер...',
                    suffixIcon: selectedTile != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              controller.clear();
                              onChanged(null);
                            },
                          )
                        : const Icon(Icons.search, size: 18),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getWallData(int index) {
    double l = double.tryParse(lengthController.text) ?? 3.0;
    double w = double.tryParse(widthController.text) ?? 2.0;
    double h = double.tryParse(heightController.text) ?? 2.5;

    switch (index) {
      case 1:
        return {
          'tile': wall1Tile,
          'width': l,
          'height': h,
          'name': 'Стена 1',
          'hasDoor': false
        };
      case 2:
        return {
          'tile': wall2Tile,
          'width': w,
          'height': h,
          'name': 'Стена 2',
          'hasDoor': false
        };
      case 3:
        return {
          'tile': wall3Tile,
          'width': l,
          'height': h,
          'name': 'Стена 3',
          'hasDoor': true
        };
      case 4:
        return {
          'tile': wall4Tile,
          'width': w,
          'height': h,
          'name': 'Стена 4',
          'hasDoor': false
        };
      default:
        return {
          'tile': null,
          'width': l,
          'height': h,
          'name': '',
          'hasDoor': false
        };
    }
  }

  Widget _buildTileGrid(DesignTile tile, double wallWidthM, double wallHeightM,
      double pxPerMeter) {
    double tWM = tile.widthCm / 100;
    double tHM = tile.heightCm / 100;
    if (tWM <= 0 || tHM <= 0) return const SizedBox();

    double tWPx = tWM * pxPerMeter;
    double tHPx = tHM * pxPerMeter;

    int cols = (wallWidthM / tWM).ceil();
    int rows = (wallHeightM / tHM).ceil();

    List<Widget> tiles = [];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        tiles.add(
          Positioned(
            left: c * tWPx,
            bottom: r * tHPx,
            width: tWPx,
            height: tHPx,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black87, width: 1.0),
              ),
              child: Image.file(
                File(tile.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) =>
                    const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        );
      }
    }

    return ClipRect(
      child: Stack(
        children: tiles,
      ),
    );
  }

  Widget _buildTexturedSurface(DesignTile? tile, double widthM, double heightM,
      String label, double pxPerMeter,
      {bool hasDoor = false}) {
    double wPx = widthM * pxPerMeter;
    double hPx = heightM * pxPerMeter;

    List<Widget> stackChildren = [];

    if (tile == null) {
      stackChildren.add(Center(
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 24))));
    } else {
      stackChildren.add(_buildTileGrid(tile, widthM, heightM, pxPerMeter));
    }

    if (hasDoor) {
      double doorWPx = 0.8 * pxPerMeter;
      double doorHPx = 2.10 * pxPerMeter;
      double centerX = wPx / 2;
      double doorLeft = centerX - doorWPx / 2;

      stackChildren.add(Positioned(
        left: doorLeft,
        bottom: 0,
        width: doorWPx,
        height: doorHPx,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border(
              top: BorderSide(color: Colors.grey.shade800, width: 3),
              left: BorderSide(color: Colors.grey.shade800, width: 3),
              right: BorderSide(color: Colors.grey.shade800, width: 3),
            ),
          ),
          child: const Center(
            child: Text('ДВЕРЬ',
                style: TextStyle(
                    color: Colors.white24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
          ),
        ),
      ));
    }

    return Container(
      width: wPx,
      height: hPx,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: tile == null ? Colors.grey.shade900 : Colors.white,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Stack(children: stackChildren),
    );
  }

  Widget _buildRoomLayout({double scale = 1.0}) {
    int leftIndex = currentViewWall == 1
        ? 2
        : (currentViewWall == 2 ? 3 : (currentViewWall == 3 ? 4 : 1));
    int centerIndex = currentViewWall;
    int rightIndex = currentViewWall == 1
        ? 4
        : (currentViewWall == 2 ? 1 : (currentViewWall == 3 ? 2 : 3));

    var leftWall = _getWallData(leftIndex);
    var centerWall = _getWallData(centerIndex);
    var rightWall = _getWallData(rightIndex);

    double pxPerMeter = 180.0;

    double cW = centerWall['width'] * pxPerMeter;
    double cH = centerWall['height'] * pxPerMeter;
    double lW = leftWall['width'] * pxPerMeter;
    double rW = rightWall['width'] * pxPerMeter;

    double totalFloorWidthM =
        leftWall['width'] + centerWall['width'] + rightWall['width'];
    double floorDepthM = (leftWall['width'] > rightWall['width']
            ? leftWall['width']
            : rightWall['width']) +
        1.5;
    double floorHPx = floorDepthM * pxPerMeter;

    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: lW + cW + rW,
        height: cH + floorHPx * 0.8,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: cH,
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateX(-1.0),
                alignment: Alignment.topCenter,
                child: _buildTexturedSurface(
                    floorTile, totalFloorWidthM, floorDepthM, 'Пол', pxPerMeter,
                    hasDoor: false),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: Transform(
                transform: Matrix4.skewY(-0.3),
                alignment: Alignment.bottomRight,
                child: _buildTexturedSurface(
                    leftWall['tile'],
                    leftWall['width'],
                    leftWall['height'],
                    leftWall['name'],
                    pxPerMeter,
                    hasDoor: leftWall['hasDoor']),
              ),
            ),
            Positioned(
              left: lW + cW,
              top: 0,
              child: Transform(
                transform: Matrix4.skewY(0.3),
                alignment: Alignment.bottomLeft,
                child: _buildTexturedSurface(
                    rightWall['tile'],
                    rightWall['width'],
                    rightWall['height'],
                    rightWall['name'],
                    pxPerMeter,
                    hasDoor: rightWall['hasDoor']),
              ),
            ),
            Positioned(
              left: lW,
              top: 0,
              child: _buildTexturedSurface(
                  centerWall['tile'],
                  centerWall['width'],
                  centerWall['height'],
                  centerWall['name'],
                  pxPerMeter,
                  hasDoor: centerWall['hasDoor']),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenVisualizer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(builder: (context, setFullState) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: const Text('3D Развертка (TV Режим)'),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [1, 2, 3, 4].map((i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: ChoiceChip(
                            label: Text('Смотреть на Стену $i',
                                style: const TextStyle(fontSize: 16)),
                            selected: currentViewWall == i,
                            selectedColor: Colors.indigo,
                            labelStyle: TextStyle(
                                color: currentViewWall == i
                                    ? Colors.white
                                    : Colors.black),
                            onSelected: (val) {
                              setFullState(() => currentViewWall = i);
                              setState(() {});
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.1,
                      maxScale: 3.0,
                      constrained: false,
                      boundaryMargin: const EdgeInsets.all(2000),
                      child: _buildRoomLayout(scale: 1.0),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _build3DRoomVisualizer() {
    return GestureDetector(
      onTap: _openFullScreenVisualizer,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade900,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
          ],
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.zoom_out_map, color: Colors.white70, size: 20),
                SizedBox(width: 8),
                Text('Нажмите для полного экрана',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: ClipRect(
                child: InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(1000),
                  child: _buildRoomLayout(scale: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printInvoice(
      List<Map<String, dynamic>> summaryItems, double grandTotal) async {
    final doc = pw.Document();

    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    doc.addPage(
      pw.Page(
        pageFormat:
            PdfPageFormat(210 * PdfPageFormat.mm, 148 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Theme(
            data: pw.ThemeData.withFont(base: font, bold: fontBold),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('НАКЛАДНАЯ',
                        style: pw.TextStyle(
                            fontSize: 15, fontWeight: pw.FontWeight.bold)),
                    pw.Text('3D Kamron',
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('+998 90 502 87 22',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.Text('Buyuk ipak yoli 11',
                              style: const pw.TextStyle(fontSize: 9)),
                        ]),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Оставили только размеры
                pw.Text(
                    'Размеры помещения: ${lengthController.text}м × ${widthController.text}м (Высота: ${heightController.text}м)',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),

                pw.Divider(height: 10),

                pw.Text('ВЫБРАННЫЕ МАТЕРИАЛЫ:',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                if (wall1Tile != null)
                  pw.Text(
                      '• Стена 1: ${wall1Tile!.name} (${wall1Tile!.widthCm.toStringAsFixed(0)}x${wall1Tile!.heightCm.toStringAsFixed(0)} см) — ${wall1Tile!.pricePerSquareMeter.toSpaceSeparated()} сум/м²',
                      style: const pw.TextStyle(fontSize: 8)),
                if (wall2Tile != null)
                  pw.Text(
                      '• Стена 2: ${wall2Tile!.name} (${wall2Tile!.widthCm.toStringAsFixed(0)}x${wall2Tile!.heightCm.toStringAsFixed(0)} см) — ${wall2Tile!.pricePerSquareMeter.toSpaceSeparated()} сум/м²',
                      style: const pw.TextStyle(fontSize: 8)),
                if (wall3Tile != null)
                  pw.Text(
                      '• Стена 3 (с дверью): ${wall3Tile!.name} (${wall3Tile!.widthCm.toStringAsFixed(0)}x${wall3Tile!.heightCm.toStringAsFixed(0)} см) — ${wall3Tile!.pricePerSquareMeter.toSpaceSeparated()} сум/м²',
                      style: const pw.TextStyle(fontSize: 8)),
                if (wall4Tile != null)
                  pw.Text(
                      '• Стена 4: ${wall4Tile!.name} (${wall4Tile!.widthCm.toStringAsFixed(0)}x${wall4Tile!.heightCm.toStringAsFixed(0)} см) — ${wall4Tile!.pricePerSquareMeter.toSpaceSeparated()} сум/м²',
                      style: const pw.TextStyle(fontSize: 8)),
                if (floorTile != null)
                  pw.Text(
                      '• Пол: ${floorTile!.name} (${floorTile!.widthCm.toStringAsFixed(0)}x${floorTile!.heightCm.toStringAsFixed(0)} см) — ${floorTile!.pricePerSquareMeter.toSpaceSeparated()} сум/м²',
                      style: const pw.TextStyle(fontSize: 8)),

                pw.SizedBox(height: 6),
                pw.Text('ИТОГОВЫЙ РАСЧЕТ:',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),

                ...summaryItems.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                            '${item['name']} (${item['totalPieces']} шт. / ${item['finalArea'].toStringAsFixed(2)} м²)',
                            style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(
                            '${(item['cost'] as double).toSpaceSeparated()} сум',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  );
                }),

                pw.Spacer(),
                pw.Divider(height: 8),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('ИТОГО К ОПЛАТЕ:',
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${grandTotal.toSpaceSeparated()} сум',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Center(
                    child: pw.Text('Спасибо за выбор 3D Kamron!',
                        style: const pw.TextStyle(
                            fontSize: 7, color: PdfColors.grey700))),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Nakladnaya_3D_Kamron',
    );
  }

  void _openPrintDialog(
      List<Map<String, dynamic>> summaryItems, double grandTotal) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🖨️ Печать накладной (Формат А5)'),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('НАКЛАДНАЯ',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo)),
                        Text('3D Kamron',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('+998 90 502 87 22',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            Text('Buyuk ipak yoli 11',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 25),

                    // Оставили только размеры
                    Text(
                        'Размеры помещения: ${lengthController.text}м × ${widthController.text}м (Высота: ${heightController.text}м)',
                        style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                            fontSize: 13)),

                    const Divider(height: 20),

                    const Text('ВЫБРАННЫЕ МАТЕРИАЛЫ:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.indigo)),
                    const SizedBox(height: 6),
                    if (wall1Tile != null)
                      Text(
                          '• Стена 1: ${wall1Tile!.name} (${wall1Tile!.widthCm.toStringAsFixed(0)}x${wall1Tile!.heightCm.toStringAsFixed(0)} см) — ${wall1Tile!.pricePerSquareMeter.toSpaceSeparated()} сум/м²',
                          style: const TextStyle(fontSize: 13)),
                    if (wall2Tile != null)
                      Text(
                          '• Стена 2: ${wall2Tile!.name} (${wall2Tile!.widthCm.toStringAsFixed(0)}x${wall2Tile!.heightCm.toStringAsFixed(0)} см) — ${wall2Tile!.pricePerSquareMeter.toSpaceSeparated()} сум/м²',
                          style: const TextStyle(fontSize: 13)),
                    if (wall3Tile != null)
                      Text(
                          '• Стена 3 (с дверью): ${wall3Tile!.name} (${wall3Tile!.widthCm.toStringAsFixed(0)}x${wall3Tile!.heightCm.toStringAsFixed(0)} см) — ${wall3Tile!.pricePerSquareMeter.toSpaceSeparated()} сум/м²',
                          style: const TextStyle(fontSize: 13)),
                    if (wall4Tile != null)
                      Text(
                          '• Стена 4: ${wall4Tile!.name} (${wall4Tile!.widthCm.toStringAsFixed(0)}x${wall4Tile!.heightCm.toStringAsFixed(0)} см) — ${wall4Tile!.pricePerSquareMeter.toSpaceSeparated()} сум/м²',
                          style: const TextStyle(fontSize: 13)),
                    if (floorTile != null)
                      Text(
                          '• Пол: ${floorTile!.name} (${floorTile!.widthCm.toStringAsFixed(0)}x${floorTile!.heightCm.toStringAsFixed(0)} см) — ${floorTile!.pricePerSquareMeter.toSpaceSeparated()} сум/м²',
                          style: const TextStyle(fontSize: 13)),

                    const Divider(height: 25),
                    const Text('ИТОГОВЫЙ РАСЧЕТ МАТЕРИАЛОВ:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.indigo)),
                    const SizedBox(height: 8),

                    ...summaryItems.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item['name']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                                '   • Количество: ${item['totalPieces']} шт. ${addReserve ? "(с запасом 5%)" : "(оптимизировано)"}',
                                style: const TextStyle(fontSize: 13)),
                            Text(
                                '   • Оплачиваемая площадь: ${item['finalArea'].toStringAsFixed(2)} м²',
                                style: const TextStyle(fontSize: 13)),
                            Text(
                                '   • Стоимость: ${(item['cost'] as double).toSpaceSeparated()} сум',
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ],
                        ),
                      );
                    }),

                    const Divider(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ИТОГО К ОПЛАТЕ:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${grandTotal.toSpaceSeparated()} сум',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Center(
                        child: Text('Спасибо за выбор 3D Kamron!',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontStyle: FontStyle.italic))),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                _printInvoice(summaryItems, grandTotal);
              },
              icon: const Icon(Icons.print),
              label: const Text('Печать накладной (А5)'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final calculation = _calculateResults();
    final List<Map<String, dynamic>> summaryItems = calculation['items'] ?? [];
    final double grandTotal = calculation['grandTotal'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
          title: const Text('Дизайн и расчет'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                        label: const Text('Туалет'),
                        selected: roomType == 'toilet',
                        onSelected: (val) =>
                            setState(() => roomType = 'toilet')),
                    const SizedBox(width: 15),
                    ChoiceChip(
                        label: const Text('Ванная'),
                        selected: roomType == 'bathroom',
                        onSelected: (val) =>
                            setState(() => roomType = 'bathroom')),
                  ],
                ),
                const Divider(height: 30),
                _build3DRoomVisualizer(),
                const SizedBox(height: 30),
                const Text('1. Размеры комнаты (метры)',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: lengthController,
                            decoration: const InputDecoration(
                                labelText: 'Длина (Стена 1/3)'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: widthController,
                            decoration: const InputDecoration(
                                labelText: 'Ширина (Стена 2/4)'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: heightController,
                            decoration:
                                const InputDecoration(labelText: 'Высота'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}))),
                  ],
                ),
                const Divider(height: 30),
                const Text('2. Выбор кафеля',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildTileSearchField('Стена 1', wall1Tile,
                    (val) => setState(() => wall1Tile = val)),
                _buildTileSearchField('Стена 2', wall2Tile,
                    (val) => setState(() => wall2Tile = val)),
                _buildTileSearchField('Стена 3 (с дверью)', wall3Tile,
                    (val) => setState(() => wall3Tile = val)),
                _buildTileSearchField('Стена 4', wall4Tile,
                    (val) => setState(() => wall4Tile = val)),
                _buildTileSearchField(
                    'Пол', floorTile, (val) => setState(() => floorTile = val)),
                const Divider(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('3. Запас на подрезку',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        const Text('Добавить 5%'),
                        Switch(
                          value: addReserve,
                          onChanged: (val) => setState(() => addReserve = val),
                          activeColor: Colors.indigo,
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 30),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Итоговый расчет материалов:',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo)),
                        const Divider(),
                        if (summaryItems.isEmpty)
                          const Text(
                              'Выберите кафель хотя бы для одной стены или пола.')
                        else
                          ...summaryItems.map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item['name']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.indigo)),
                                  Text(
                                      '• Количество: ${item['totalPieces']} шт. ${addReserve ? "(с запасом)" : "(оптимизировано)"}'),
                                  Text(
                                      '• Оплачиваемая площадь: ${item['finalArea'].toStringAsFixed(2)} м²'),
                                  Text(
                                      '• Стоимость: ${(item['cost'] as double).toSpaceSeparated()} сум',
                                      style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  const Divider(height: 10),
                                ],
                              ),
                            );
                          }),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Общая сумма:',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('${grandTotal.toSpaceSeparated()} сум',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () =>
                                _openPrintDialog(summaryItems, grandTotal),
                            icon: const Icon(Icons.print),
                            label: const Text('🖨️ Печать накладной (А5)',
                                style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
