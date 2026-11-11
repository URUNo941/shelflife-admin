import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// หน้าสแกนบาร์โค้ด / QR ด้วยกล้อง
/// สแกนเจอแล้วจะปิดหน้านี้และส่งค่ากลับ: `final code = await Navigator.push<String>(...)`
class UserScanView extends StatefulWidget {
  const UserScanView({super.key});

  @override
  State<UserScanView> createState() => _UserScanViewState();
}

class _UserScanViewState extends State<UserScanView> {
  final MobileScannerController _controller = MobileScannerController();
  bool _done = false; // กันไม่ให้ pop ซ้ำเมื่อสแกนเจอหลายเฟรม

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final code =
        capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (code == null || code.isEmpty) return;
    _done = true;
    Navigator.pop(context, code);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan barcode / QR'),
        actions: [
          IconButton(
            tooltip: 'Flashlight',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Text(
              'Point the camera at the product barcode or QR code',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
