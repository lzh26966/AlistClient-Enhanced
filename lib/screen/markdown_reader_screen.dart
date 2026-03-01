import 'package:alist/l10n/intl_keys.dart';
import 'package:alist/util/download/download_manager.dart';
import 'package:alist/util/download/download_task.dart';
import 'package:alist/util/download/download_task_status.dart';
import 'package:alist/util/file_type.dart';
import 'package:alist/util/file_utils.dart';
import 'package:alist/widget/alist_scaffold.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class MarkdownReaderScreen extends StatelessWidget {
  MarkdownReaderScreen({Key? key}) : super(key: key);
  final MarkdownReaderItem _markdownReaderItem = Get.arguments["markdownReaderItem"];

  @override
  Widget build(BuildContext context) {
    return AlistScaffold(
      appbarTitle: Text(_markdownReaderItem.name),
      body: _MarkdownReaderContainer(markdownReaderItem: _markdownReaderItem),
    );
  }
}

class MarkdownReaderItem {
  final String path;
  final String? sign;
  final String name;
  final FileType fileType;

  MarkdownReaderItem(this.path, this.sign, this.name, this.fileType);
}

class _MarkdownReaderContainer extends StatefulWidget {
  const _MarkdownReaderContainer({Key? key, required this.markdownReaderItem})
      : super(key: key);
  final MarkdownReaderItem markdownReaderItem;

  @override
  State<_MarkdownReaderContainer> createState() => _MarkdownReaderContainerState();
}

class _MarkdownReaderContainerState extends State<_MarkdownReaderContainer> {
  String? _localPath;
  int _downloadProgress = 0;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  String? _markdownContent;
  String? _errorMessage;
  DownloadTask? _downloadTask;
  late StreamSubscription _downloadProgressSubscription;
  late StreamSubscription _downloadStatusChangeSubscription;

  @override
  void initState() {
    super.initState();
    _checkAndDownload();
  }

  @override
  void dispose() {
    _downloadProgressSubscription.cancel();
    _downloadStatusChangeSubscription.cancel();
    super.dispose();
  }

  Future<void> _checkAndDownload() async {
    // Check if file is already downloaded
    final localPath = await DownloadManager.instance.getLocalPath(
      widget.markdownReaderItem.path,
      widget.markdownReaderItem.sign,
    );
    
    if (localPath != null && await File(localPath).exists()) {
      setState(() {
        _localPath = localPath;
        _isDownloaded = true;
      });
      _loadMarkdownContent();
      return;
    }

    // Request storage permission
    if (!await _requestStoragePermission()) {
      setState(() {
        _errorMessage = "Storage permission denied";
      });
      return;
    }

    // Start download
    _startDownload();
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.storage.isGranted) {
      return true;
    }
    
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  void _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      _downloadTask = await DownloadManager.instance.download(
        widget.markdownReaderItem.path,
        widget.markdownReaderItem.sign,
        widget.markdownReaderItem.name,
        widget.markdownReaderItem.fileType,
      );

      _downloadProgressSubscription = _downloadTask!.progressStream.listen((progress) {
        setState(() {
          _downloadProgress = progress;
        });
      });

      _downloadStatusChangeSubscription = _downloadTask!.statusStream.listen((status) {
        if (status == DownloadTaskStatus.completed) {
          setState(() {
            _isDownloading = false;
            _isDownloaded = true;
            _localPath = _downloadTask!.localPath;
          });
          _loadMarkdownContent();
        } else if (status == DownloadTaskStatus.failed) {
          setState(() {
            _isDownloading = false;
            _errorMessage = "Download failed";
          });
        }
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _errorMessage = "Download error: $e";
      });
    }
  }

  Future<void> _loadMarkdownContent() async {
    if (_localPath == null) return;

    try {
      final file = File(_localPath!);
      final content = await file.readAsString();
      
      setState(() {
        _markdownContent = content;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to read file: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: Colors.red)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkAndDownload,
              child: Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (_isDownloading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Downloading... $_downloadProgress%"),
          ],
        ),
      );
    }

    if (_markdownContent == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Markdown(
      data: _markdownContent!,
      styleSheet: MarkdownStyleSheet(
        h1: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        h2: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        h3: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        p: TextStyle(fontSize: 16),
        code: TextStyle(fontFamily: 'monospace', fontSize: 14),
        blockquote: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      ),
      onTapLink: (text, href, title) {
        if (href != null) {
          // Handle link clicks
          SmartDialog.showToast("Link: $href");
        }
      },
    );
  }
}