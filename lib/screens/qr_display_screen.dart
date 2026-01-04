import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../utils/file_chunker.dart';

class QRDisplayScreen extends StatefulWidget {
  const QRDisplayScreen({super.key});

  @override
  State<QRDisplayScreen> createState() => _QRDisplayScreenState();
}

class _QRDisplayScreenState extends State<QRDisplayScreen> {
  List<String> _qrDataBlocks = [];
  String? _fileName;
  bool _isLoading = false;
  int _currentIndex = 0;
  Timer? _autoSwitchTimer;
  bool _isAutoSwitching = false;
  Duration _switchInterval = const Duration(milliseconds: 1000); // Default 1 second

  @override
  void dispose() {
    _autoSwitchTimer?.cancel();
    super.dispose();
  }

  void _startAutoSwitch() {
    if (_qrDataBlocks.isEmpty) return;
    
    _autoSwitchTimer?.cancel();
    _autoSwitchTimer = Timer.periodic(_switchInterval, (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _qrDataBlocks.length;
        });
      }
    });
    setState(() {
      _isAutoSwitching = true;
    });
  }

  void _stopAutoSwitch() {
    _autoSwitchTimer?.cancel();
    setState(() {
      _isAutoSwitching = false;
    });
  }

  void _toggleAutoSwitch() {
    if (_isAutoSwitching) {
      _stopAutoSwitch();
    } else {
      _startAutoSwitch();
    }
  }

  Future<void> _showIntervalDialog() async {
    double intervalMs = _switchInterval.inMilliseconds.toDouble();
    
    final result = await showDialog<double>(
      context: context,
      builder: (context) => _IntervalDialog(initialValue: intervalMs),
    );

    if (result != null) {
      final wasRunning = _isAutoSwitching;
      _stopAutoSwitch();
      
      setState(() {
        _switchInterval = Duration(milliseconds: result.round());
      });

      if (wasRunning) {
        _startAutoSwitch();
      }
    }
  }

  Future<void> _pickFile() async {
    _stopAutoSwitch();
    setState(() {
      _isLoading = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);
        _fileName = result.files.single.name;

        // Read file as bytes
        final bytes = await file.readAsBytes();

        // Generate QR code blocks
        final blocks = FileChunker.generateQRBlocks(bytes, _fileName!);

        setState(() {
          _qrDataBlocks = blocks;
          _currentIndex = 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('FlutDataStream'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _qrDataBlocks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.qr_code_scanner,
                        size: 100,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No file selected',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.file_upload),
                        label: const Text('Select File'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // File info and navigation
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: Column(
                        children: [
                          Text(
                            _fileName ?? 'Unknown file',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'QR Code ${_currentIndex + 1} of ${_qrDataBlocks.length}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // QR Code display
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: QrImageView(
                                    data: _qrDataBlocks[_currentIndex],
                                    version: QrVersions.auto,
                                    size: 300.0,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _currentIndex == 0
                                      ? 'Header Block'
                                      : 'Data Block $_currentIndex',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Navigation buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _currentIndex > 0
                                    ? () {
                                        _stopAutoSwitch();
                                        setState(() {
                                          _currentIndex--;
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Previous'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _stopAutoSwitch();
                                  setState(() {
                                    _qrDataBlocks = [];
                                    _currentIndex = 0;
                                    _fileName = null;
                                  });
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('New File'),
                              ),
                              ElevatedButton.icon(
                                onPressed: _currentIndex < _qrDataBlocks.length - 1
                                    ? () {
                                        _stopAutoSwitch();
                                        setState(() {
                                          _currentIndex++;
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('Next'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _toggleAutoSwitch,
                                icon: Icon(_isAutoSwitching ? Icons.pause : Icons.play_arrow),
                                label: Text(_isAutoSwitching ? 'Pause' : 'Auto Switch'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isAutoSwitching
                                      ? Colors.orange
                                      : Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: _showIntervalDialog,
                                icon: const Icon(Icons.timer),
                                label: Text(
                                  '${_switchInterval.inMilliseconds}ms',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _IntervalDialog extends StatefulWidget {
  final double initialValue;

  const _IntervalDialog({required this.initialValue});

  @override
  State<_IntervalDialog> createState() => _IntervalDialogState();
}

class _IntervalDialogState extends State<_IntervalDialog> {
  late double _intervalMs;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _intervalMs = widget.initialValue.clamp(10.0, 5000.0);
    _textController = TextEditingController(text: _intervalMs.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _updateFromSlider(double value) {
    setState(() {
      _intervalMs = value;
      _textController.text = value.toStringAsFixed(2);
    });
  }

  void _updateFromText(String text) {
    final value = double.tryParse(text);
    if (value != null) {
      final clamped = value.clamp(10.0, 5000.0);
      setState(() {
        _intervalMs = clamped;
        _textController.text = clamped.toStringAsFixed(2);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Switch Interval'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Interval (ms)',
              hintText: '10 - 5000',
              border: OutlineInputBorder(),
            ),
            onChanged: _updateFromText,
          ),
          const SizedBox(height: 16),
          Slider(
            value: _intervalMs,
            min: 10.0,
            max: 5000.0,
            divisions: 499, // 10ms steps
            label: '${_intervalMs.toStringAsFixed(0)} ms',
            onChanged: _updateFromSlider,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '10 ms',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '5000 ms (5s)',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_intervalMs),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

