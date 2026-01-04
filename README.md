# FlutDataStream

<video src="https://github.com/demensdeum/FlutDataStream/raw/refs/heads/main/demo.mp4"></video>

A Flutter application that converts any file into a series of machine-readable codes (QR & DataMatrix) for high-speed data streaming between devices.

## Features

- **Dual Encoding**: Presents each data block as both a QR Code and a DataMatrix code simultaneously.
- **High-Speed Streaming**: Supports an automatic switching interval as fast as 330ms.
- **Intelligent Chunking**: Automatically splits files into configurable chunks (default: 512 bytes).
- **Verbose Scanner**: Real-time ASCII readout of the currently scanned code for debugging and immediate feedback.
- **Automatic Reconstruction**: Instantly reconstructs and saves files to the downloads directory.
- **System Integration**: Automatically opens the saved file using the default system application upon completion.

## Setup

1. Make sure you have Flutter installed on your system
   ```bash
   flutter --version
   ```

2. Install dependencies
   ```bash
   flutter pub get
   ```

3. Run the app
   ```bash
   flutter run
   ```

## How It Works

1. **File Selection**: Choose any file from your device.
2. **Chunking**: The file is split into chunks (default: 512 bytes).
3. **Encoding**:
   - A **Header Block** is generated with file metadata (name, size, total block count).
   - Multiple **Data Blocks** are generated for the actual content (Base64 encoded).
4. **Data Transmission**: 
   - Cycle through codes manually or use **Auto Switch** (default: 330ms) to "stream" the data to another device's camera.
5. **Collection & Reconstruction**: The receiving device scans all blocks (including the header) and automatically saves and opens the reconstructed file.

## QR / DataMatrix Format

The protocol uses a pipe-separated format for reliability and efficient parsing.

### Header Block
```
FlutDataStreamHeaderBlock|{"fileName":"example.txt","fileSize":12345,"totalBlocks":7,"blockSize":512}
```

### Data Blocks
```
FlutDataStreamBlock|1|[base64 encoded data]
FlutDataStreamBlock|2|[base64 encoded data]
...
```

## Dependencies

- `qr_flutter`: QR code generation
- `barcode_widget`: DataMatrix code generation
- `mobile_scanner`: High-performance camera scanning
- `open_filex`: Cross-platform file opening
- `file_picker`: File selection from device
- `path_provider`: File system access
- `permission_handler`: Android/iOS permission management

## Platform Support

- Android
- iOS
- Windows
- macOS
- Linux
- Web

## Inspired by Projects

- [txqr](https://github.com/divan/txqr)
- [qram](https://github.com/digitalbazaar/qram)
- [qrfontain](https://github.com/dridk/qrfontain)
