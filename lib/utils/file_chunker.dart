import 'dart:typed_data';
import 'dart:convert';

class FileChunker {
  // Maximum data size per QR code (considering QR code capacity)
  // Using version 40 (177x177) which can hold ~2953 bytes in binary mode
  // We'll use a conservative 2000 bytes per block to ensure reliability
  static const int maxDataSizePerBlock = 2000;
  static const int maxHeaderSize = 2000;

  /// Generates QR code blocks from file bytes
  /// Returns a list of strings where:
  /// - First element is the header block starting with "FlutDataStreamHeaderBlock"
  /// - Subsequent elements are data blocks starting with "FlutDataStreamBlock[number]"
  static List<String> generateQRBlocks(Uint8List fileBytes, String fileName) {
    final List<String> blocks = [];

    // Calculate number of data blocks needed
    final int totalDataBlocks = (fileBytes.length / maxDataSizePerBlock).ceil();

    // Create header block
    final headerData = {
      'fileName': fileName,
      'fileSize': fileBytes.length,
      'totalBlocks': totalDataBlocks,
      'blockSize': maxDataSizePerBlock,
    };

    final headerJson = jsonEncode(headerData);
    final headerBlock = 'FlutDataStreamHeaderBlock$headerJson';
    
    // Verify header fits in QR code capacity
    if (headerBlock.length > maxHeaderSize) {
      throw Exception('Header block too large. File name may be too long.');
    }

    blocks.add(headerBlock);

    // Create data blocks
    for (int i = 0; i < totalDataBlocks; i++) {
      final startIndex = i * maxDataSizePerBlock;
      final endIndex = (startIndex + maxDataSizePerBlock < fileBytes.length)
          ? startIndex + maxDataSizePerBlock
          : fileBytes.length;

      final chunk = fileBytes.sublist(startIndex, endIndex);
      
      // Encode chunk as base64 to ensure safe transmission in QR code
      final base64Chunk = base64Encode(chunk);
      
      // Format: FlutDataStreamBlock[number]base64data
      final blockNumber = i + 1; // Blocks are numbered starting from 1
      final dataBlock = 'FlutDataStreamBlock$blockNumber$base64Chunk';
      
      blocks.add(dataBlock);
    }

    return blocks;
  }
}

