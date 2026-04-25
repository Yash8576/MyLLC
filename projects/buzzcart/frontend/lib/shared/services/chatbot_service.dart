import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatbotService {
  final String baseUrl;
  final String? apiKey;

  ChatbotService({
    required this.baseUrl,
    this.apiKey,
  });

  Future<ProductDocumentAnswer> askProductDocument({
    required String productId,
    required String query,
    String? productName,
    String? userId,
    String? documentUrl,
    bool forceDocumentSync = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/chat/message'),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'product_id': productId,
          'query': query,
          if (productName != null && productName.isNotEmpty)
            'product_name': productName,
          if (userId != null) 'user_id': userId,
          if (documentUrl != null && documentUrl.isNotEmpty)
            'document_url': documentUrl,
          'force_document_sync': forceDocumentSync,
        }),
      );

      if (response.statusCode == 200) {
        return ProductDocumentAnswer.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }

      throw ChatbotException(
        'Failed to query product document: ${response.statusCode}',
        response.body,
      );
    } catch (e) {
      if (e is ChatbotException) rethrow;
      throw ChatbotException('Network error: $e');
    }
  }

  Future<DocumentSyncResponse> syncProductDocument({
    required String productId,
    required String documentUrl,
    String? filename,
    bool force = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/documents/sync'),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'product_id': productId,
          'document_url': documentUrl,
          if (filename != null && filename.isNotEmpty) 'filename': filename,
          'force': force,
        }),
      );

      if (response.statusCode == 200) {
        return DocumentSyncResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }

      throw ChatbotException(
        'Failed to sync product document: ${response.statusCode}',
        response.body,
      );
    } catch (e) {
      if (e is ChatbotException) rethrow;
      throw ChatbotException('Network error: $e');
    }
  }

  Future<ProductDocumentStatus> getProductDocumentStatus(
      String productId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/documents/$productId'),
        headers: {
          if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        },
      );

      if (response.statusCode == 200) {
        return ProductDocumentStatus.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }

      throw ChatbotException(
        'Failed to load product document status: ${response.statusCode}',
        response.body,
      );
    } catch (e) {
      if (e is ChatbotException) rethrow;
      throw ChatbotException('Network error: $e');
    }
  }

  Future<void> deleteProductDocument(String productId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/documents/$productId'),
        headers: {
          if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        },
      );

      if (response.statusCode != 200) {
        throw ChatbotException(
          'Failed to delete product document index: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      if (e is ChatbotException) rethrow;
      throw ChatbotException('Network error: $e');
    }
  }

  Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/v1/health'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class ProductDocumentAnswer {
  final String answer;
  final ProductDocumentSource? source;
  final String confidence;

  ProductDocumentAnswer({
    required this.answer,
    required this.source,
    required this.confidence,
  });

  bool get hasSource => source != null;

  factory ProductDocumentAnswer.fromJson(Map<String, dynamic> json) {
    return ProductDocumentAnswer(
      answer: json['answer'] as String? ?? '',
      source: json['source'] is Map<String, dynamic>
          ? ProductDocumentSource.fromJson(
              json['source'] as Map<String, dynamic>,
            )
          : null,
      confidence: json['confidence'] as String? ?? 'low',
    );
  }
}

class ProductDocumentSource {
  final int page;
  final int chunkId;

  ProductDocumentSource({
    required this.page,
    required this.chunkId,
  });

  factory ProductDocumentSource.fromJson(Map<String, dynamic> json) {
    return ProductDocumentSource(
      page: json['page'] as int? ?? 0,
      chunkId: json['chunk_id'] as int? ?? 0,
    );
  }
}

class DocumentSyncResponse {
  final String productId;
  final bool indexed;
  final int chunksCreated;
  final int pagesProcessed;
  final String? sourceName;
  final String? documentUrl;
  final String status;
  final String message;
  final DateTime updatedAt;

  DocumentSyncResponse({
    required this.productId,
    required this.indexed,
    required this.chunksCreated,
    required this.pagesProcessed,
    required this.sourceName,
    required this.documentUrl,
    required this.status,
    required this.message,
    required this.updatedAt,
  });

  factory DocumentSyncResponse.fromJson(Map<String, dynamic> json) {
    return DocumentSyncResponse(
      productId: json['product_id'] as String? ?? '',
      indexed: json['indexed'] as bool? ?? false,
      chunksCreated: json['chunks_created'] as int? ?? 0,
      pagesProcessed: json['pages_processed'] as int? ?? 0,
      sourceName: json['source_name'] as String?,
      documentUrl: json['document_url'] as String?,
      status: json['status'] as String? ?? '',
      message: json['message'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ProductDocumentStatus {
  final String productId;
  final bool indexed;
  final int chunksCreated;
  final int pagesProcessed;
  final String? sourceName;
  final String? documentUrl;
  final DateTime? updatedAt;

  ProductDocumentStatus({
    required this.productId,
    required this.indexed,
    required this.chunksCreated,
    required this.pagesProcessed,
    required this.sourceName,
    required this.documentUrl,
    required this.updatedAt,
  });

  factory ProductDocumentStatus.fromJson(Map<String, dynamic> json) {
    return ProductDocumentStatus(
      productId: json['product_id'] as String? ?? '',
      indexed: json['indexed'] as bool? ?? false,
      chunksCreated: json['chunks_created'] as int? ?? 0,
      pagesProcessed: json['pages_processed'] as int? ?? 0,
      sourceName: json['source_name'] as String?,
      documentUrl: json['document_url'] as String?,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}

class ChatbotException implements Exception {
  final String message;
  final String? details;

  ChatbotException(this.message, [this.details]);

  @override
  String toString() => details != null ? '$message: $details' : message;
}
