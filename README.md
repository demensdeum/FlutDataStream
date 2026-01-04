# FlutDataStream

A Flutter application that converts any file into a series of QR codes for data streaming.

## Features

- Select any file from your device
- Automatically splits the file into chunks
- Generates QR codes with:
  - **Header Block**: Contains file metadata (name, size, total block count) starting with `FlutDataStreamHeaderBlock`
  - **Data Blocks**: Contains file data chunks starting with `FlutDataStreamBlock[number]` (e.g., `FlutDataStreamBlock1`)

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

1. **File Selection**: Use the "Select File" button to choose any file from your device
2. **Chunking**: The file is automatically split into chunks of ~2000 bytes each
3. **QR Code Generation**: 
   - First QR code contains the header with file information
   - Subsequent QR codes contain the actual file data (base64 encoded)
4. **Navigation**: Use Previous/Next buttons to navigate through all QR codes

## QR Code Format

### Header Block
```
FlutDataStreamHeaderBlock{"fileName":"example.txt","fileSize":12345,"totalBlocks":7,"blockSize":2000}
```

### Data Blocks
```
FlutDataStreamBlock1[base64 encoded data]
FlutDataStreamBlock2[base64 encoded data]
...
```

## Dependencies

- `qr_flutter`: QR code generation and display
- `file_picker`: File selection from device
- `path_provider`: File system access

## Platform Support

- Android
- iOS
- Windows
- macOS
- Linux
- Web

