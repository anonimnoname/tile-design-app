class DesignTile {
  final int? id;
  final String name;
  final double widthCm; // ширина в см
  final double heightCm; // длина в см
  final double pricePerSquareMeter; // цена за 1 кв.м
  final String imagePath; // фото или ссылка

  DesignTile({
    this.id,
    required this.name,
    required this.widthCm,
    required this.heightCm,
    required this.pricePerSquareMeter,
    required this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'widthCm': widthCm,
      'heightCm': heightCm,
      'pricePerSquareMeter': pricePerSquareMeter,
      'imagePath': imagePath,
    };
  }

  factory DesignTile.fromMap(Map<String, dynamic> map) {
    return DesignTile(
      id: map['id'],
      name: map['name'],
      widthCm: map['widthCm'],
      heightCm: map['heightCm'],
      pricePerSquareMeter: map['pricePerSquareMeter'],
      imagePath: map['imagePath'] ?? '',
    );
  }
}

// Расширение для красивого форматирования цен с пробелами
extension PriceFormatting on double {
  String toSpaceSeparated() {
    String priceStr = toStringAsFixed(0); // убираем копейки
    // Регулярное выражение, которое ставит пробел каждые 3 цифры с конца
    return priceStr.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');
  }
}
