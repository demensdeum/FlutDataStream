import 'dart:typed_data';
import 'dart:convert';

class FileChunker {
  // Maximum data size per QR code (considering QR code capacity)
  // Using version 40 (177x177) which can hold ~2953 bytes in binary mode
  // Default is 2000 bytes per block to ensure reliability
  static const int maxHeaderSize = 2000;

  /// Generates QR code blocks from file bytes
  /// Returns a list of strings where:
  /// - First element is the header block starting with "FlutDataStreamHeaderBlock"
  /// - Subsequent elements are data blocks starting with "FlutDataStreamBlock[number]"
  /// 
  /// [chunkSize] - Size of each data chunk in bytes (default: 256, max: 2048)
  static List<String> generateQRBlocks(
    Uint8List fileBytes,
    String fileName, {
    int chunkSize = 512,
  }) {
    // Validate chunk size
    if (chunkSize < 32 || chunkSize > 2048) {
      throw Exception('Chunk size must be between 32 and 2048 bytes');
    }

    final List<String> blocks = [];

    // Calculate number of data blocks needed
    final int totalDataBlocks = (fileBytes.length / chunkSize).ceil();

    // Create header block
    final headerData = {
      'fileName': fileName,
      'fileSize': fileBytes.length,
      'totalBlocks': totalDataBlocks,
      'blockSize': chunkSize,
    };

    final headerJson = jsonEncode(headerData);
    final headerBlock = 'FlutDataStreamHeaderBlock|$headerJson';
    
    // Verify header fits in QR code capacity
    if (headerBlock.length > maxHeaderSize) {
      throw Exception('Header block too large. File name may be too long.');
    }

    blocks.add(headerBlock);

    // Create data blocks
    for (int i = 0; i < totalDataBlocks; i++) {
      final startIndex = i * chunkSize;
      final endIndex = (startIndex + chunkSize < fileBytes.length)
          ? startIndex + chunkSize
          : fileBytes.length;

      final chunk = fileBytes.sublist(startIndex, endIndex);
      
      // Encode chunk as base64 to ensure safe transmission in QR code
      final base64Chunk = base64Encode(chunk);
      
      // Format: FlutDataStreamBlock|[number]|[base64data]
      final blockNumber = i + 1; // Blocks are numbered starting from 1
      final dataBlock = 'FlutDataStreamBlock|$blockNumber|$base64Chunk';
      
      blocks.add(dataBlock);
    }

    return blocks;
  }
}

