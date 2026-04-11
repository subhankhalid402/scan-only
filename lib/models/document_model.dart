class DocumentModel {
  final int? id;
  final String name;
  final String filePath;
  final String fileType; // 'pdf', 'jpg', 'png'
  final String scanType; // 'document', 'id_card', 'receipt', 'qr'
  final int pageCount;
  final double fileSizeMB;
  final DateTime createdAt;
  final DateTime? modifiedAt;
  final bool isFavorite;
  final String? thumbnailPath;
  final String? ocrText;
  final List<String> tags;

  DocumentModel({
    this.id,
    required this.name,
    required this.filePath,
    required this.fileType,
    required this.scanType,
    required this.pageCount,
    required this.fileSizeMB,
    required this.createdAt,
    this.modifiedAt,
    this.isFavorite = false,
    this.thumbnailPath,
    this.ocrText,
    this.tags = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'filePath': filePath,
      'fileType': fileType,
      'scanType': scanType,
      'pageCount': pageCount,
      'fileSizeMB': fileSizeMB,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
      'isFavorite': isFavorite ? 1 : 0,
      'thumbnailPath': thumbnailPath,
      'ocrText': ocrText,
      'tags': tags.join(','),
    };
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'],
      name: map['name'],
      filePath: map['filePath'],
      fileType: map['fileType'],
      scanType: map['scanType'],
      pageCount: map['pageCount'],
      fileSizeMB: map['fileSizeMB'],
      createdAt: DateTime.parse(map['createdAt']),
      modifiedAt: map['modifiedAt'] != null
          ? DateTime.parse(map['modifiedAt'])
          : null,
      isFavorite: map['isFavorite'] == 1,
      thumbnailPath: map['thumbnailPath'],
      ocrText: map['ocrText'],
      tags: map['tags'] != null && map['tags'].toString().isNotEmpty
          ? map['tags'].toString().split(',')
          : [],
    );
  }

  DocumentModel copyWith({
    int? id,
    String? name,
    String? filePath,
    String? fileType,
    String? scanType,
    int? pageCount,
    double? fileSizeMB,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isFavorite,
    String? thumbnailPath,
    String? ocrText,
    List<String>? tags,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      scanType: scanType ?? this.scanType,
      pageCount: pageCount ?? this.pageCount,
      fileSizeMB: fileSizeMB ?? this.fileSizeMB,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      ocrText: ocrText ?? this.ocrText,
      tags: tags ?? this.tags,
    );
  }
}
