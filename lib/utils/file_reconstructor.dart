import 'dart:typed_data';
import 'dart:convert';

class FileReconstructor {
  /// Parses a QR code string and extracts header or data block information
  /// Returns a map with 'type' ('header' or 'data'), and relevant data
  static Map<String, dynamic>? parseQRCode(String qrData) {
    if (qrData.startsWith('FlutDataStreamHeaderBlock')) {
      // Extract header JSON
      final jsonStr = qrData.substring('FlutDataStreamHeaderBlock'.length);
      try {
        final headerData = jsonDecode(jsonStr) as Map<String, dynamic>;
        return {
          'type': 'header',
          'fileName': headerData['fileName'] as String,
          'fileSize': headerData['fileSize'] as int,
          'totalBlocks': headerData['totalBlocks'] as int,
          'blockSize': headerData['blockSize'] as int,
        };
      } catch (e) {
        return null;
      }
    } else if (qrData.startsWith('FlutDataStreamBlock')) {
      // Extract block number and data
      // Format: FlutDataStreamBlock[number][base64data]
      final remaining = qrData.substring('FlutDataStreamBlock'.length);
      
      // Find where the number ends (first non-digit character)
      int blockNumberEnd = 0;
      for (int i = 0; i < remaining.length; i++) {
        if (!RegExp(r'[0-9]').hasMatch(remaining[i])) {
          blockNumberEnd = i;
          break;
        }
      }
      
      if (blockNumberEnd == 0) return null;
      
      final blockNumber = int.tryParse(remaining.substring(0, blockNumberEnd));
      if (blockNumber == null) return null;
      
      final base64Data = remaining.substring(blockNumberEnd);
      
      try {
        final bytes = base64Decode(base64Data);
        return {
          'type': 'data',
          'blockNumber': blockNumber,
          'data': bytes,
        };
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }

  /// Reconstructs file from collected blocks
  /// Returns the file bytes if all blocks are collected, null otherwise
  static Uint8List? reconstructFile({
    required Map<String, dynamic> header,
    required Map<int, Uint8List> dataBlocks,
  }) {
    final totalBlocks = header['totalBlocks'] as int;
    final fileSize = header['fileSize'] as int;
    
    // Check if we have all blocks
    if (dataBlocks.length != totalBlocks) {
      return null;
    }
    
    // Verify we have blocks 1 through totalBlocks
    for (int i = 1; i <= totalBlocks; i++) {
      if (!dataBlocks.containsKey(i)) {
        return null;
      }
    }
    
    // Reconstruct file
    final List<int> fileBytes = [];
    for (int i = 1; i <= totalBlocks; i++) {
      fileBytes.addAll(dataBlocks[i]!);
    }
    
    // Trim to exact file size (in case last block has padding)
    final result = Uint8List.fromList(fileBytes);
    if (result.length > fileSize) {
      return result.sublist(0, fileSize);
    }
    
    return result;
  }
}

