import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import '../utils/file_reconstructor.dart';

class QRImportScreen extends StatefulWidget {
  const QRImportScreen({super.key});

  @override
  State<QRImportScreen> createState() => _QRImportScreenState();
}

class _QRImportScreenState extends State<QRImportScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  Map<String, dynamic>? _header;
  Map<int, Uint8List> _dataBlocks = {};
  bool _isScanning = true;
  bool _isReconstructing = false;
  Set<String> _scannedCodes = {}; // Track scanned codes to avoid duplicates
  String? _lastScannedBlock; // Track last successfully scanned block
  String? _currentRawValue; // Track currently visible raw QR value

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.camera.request();
      // For Android 13+, use photos permission instead of storage
      if (await Permission.photos.isDenied) {
        await Permission.photos.request();
      }
      // For older Android versions
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    }
  }

  Future<String?> _getDownloadsPath() async {
    if (Platform.isAndroid) {
      // Try multiple common Android download paths
      final paths = [
        '/storage/emulated/0/Download',
        '/sdcard/Download',
        '/storage/sdcard0/Download',
      ];
      
      for (final path in paths) {
        final directory = Directory(path);
        if (await directory.exists()) {
          return directory.path;
        }
      }
      
      // Fallback to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      return downloadsDir.path;
    } else if (Platform.isIOS) {
      // For iOS, use app documents directory
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } else {
      // For other platforms, use downloads directory
      final directory = await getDownloadsDirectory();
      return directory?.path;
    }
  }

  Future<void> _saveFile(Uint8List fileBytes, String fileName) async {
    try {
      final downloadsPath = await _getDownloadsPath();
      if (downloadsPath == null) {
        throw Exception('Could not access downloads directory');
      }

      final file = File('$downloadsPath/$fileName');
      await file.writeAsBytes(fileBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved to: ${file.path}'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
        
        // Open the file automatically
        try {
          await OpenFilex.open(file.path);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open file: $e')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _processQRCode(String? code) {
    if (code != _currentRawValue) {
      setState(() {
        _currentRawValue = code;
      });
    }

    if (code == null || _scannedCodes.contains(code)) {
      return; // Skip null or already scanned codes
    }

    _scannedCodes.add(code);

    final parsed = FileReconstructor.parseQRCode(code);
    if (parsed == null) {
      return; // Not a valid FlutDataStream QR code
    }

    setState(() {
      if (parsed['type'] == 'header') {
        _header = parsed;
        _dataBlocks.clear(); // Reset data blocks when new header is scanned
        _scannedCodes.clear(); // Reset scanned codes
        _scannedCodes.add(code); // Keep the header in scanned codes
        _lastScannedBlock = 'Header Block';
      } else if (parsed['type'] == 'data') {
        if (_header != null) {
          final blockNumber = parsed['blockNumber'] as int;
          _dataBlocks[blockNumber] = parsed['data'] as Uint8List;
          _lastScannedBlock = 'Data Block $blockNumber';
        }
      }
    });

    // Check if we have all blocks and can reconstruct
    if (_header != null) {
      final totalBlocks = _header!['totalBlocks'] as int;
      if (_dataBlocks.length == totalBlocks) {
        _reconstructFile();
      }
    }
  }

  Future<void> _reconstructFile() async {
    if (_header == null) return;

    setState(() {
      _isReconstructing = true;
      _isScanning = false;
    });

    try {
      final fileBytes = FileReconstructor.reconstructFile(
        header: _header!,
        dataBlocks: _dataBlocks,
      );

      if (fileBytes != null) {
        final fileName = _header!['fileName'] as String;
        await _saveFile(fileBytes, fileName);

        // Reset for next file
        setState(() {
          _header = null;
          _dataBlocks.clear();
          _scannedCodes.clear();
          _isReconstructing = false;
          _isScanning = true;
        });
      } else {
        throw Exception('Failed to reconstruct file');
      }
    } catch (e) {
      setState(() {
        _isReconstructing = false;
        _isScanning = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reconstructing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _header = null;
      _dataBlocks.clear();
      _scannedCodes.clear();
      _isScanning = true;
      _isReconstructing = false;
      _lastScannedBlock = null;
      _currentRawValue = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Import from QR Codes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          if (_header != null || _dataBlocks.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Column(
                children: [
                  if (_header != null) ...[
                    Text(
                      'File: ${_header!['fileName']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Blocks collected: ${_dataBlocks.length}${_header != null ? ' / ${_header!['totalBlocks']}' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_lastScannedBlock != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Last scanned: $_lastScannedBlock',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_header != null && _dataBlocks.length < (_header!['totalBlocks'] as int))
                    const SizedBox(height: 8),
                  if (_header != null && _dataBlocks.length < (_header!['totalBlocks'] as int))
                    LinearProgressIndicator(
                      value: _dataBlocks.length / (_header!['totalBlocks'] as int),
                    ),
                ],
              ),
            ),

          // Scanner or status
          Expanded(
            child: _isReconstructing
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Reconstructing file...'),
                      ],
                    ),
                  )
                : _isScanning
                    ? Stack(
                        children: [
                          MobileScanner(
                            controller: _scannerController,
                            onDetect: (capture) {
                              final List<Barcode> barcodes = capture.barcodes;
                              for (final barcode in barcodes) {
                                if (barcode.rawValue != null) {
                                  _processQRCode(barcode.rawValue);
                                }
                              }
                            },
                          ),
                          // Verbose raw readout overlay
                          if (_currentRawValue != null)
                            Positioned(
                              top: 20,
                              left: 20,
                              right: 20,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'SCANNER READOUT (ASCII):',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _currentRawValue!.length > 100
                                          ? '${_currentRawValue!.substring(0, 100)}...'
                                          : _currentRawValue!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Overlay with instructions
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.black.withOpacity(0.7),
                              child: const Text(
                                'Point camera at QR codes. Start with the header block, then scan all data blocks.',
                                style: TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: Text('Ready to scan'),
                      ),
          ),
        ],
      ),
    );
  }
}

