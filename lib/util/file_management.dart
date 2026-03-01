import 'dart:io';
import 'package:alist/l10n/intl_keys.dart';
import 'package:alist/util/file_type.dart';
import 'package:alist/util/file_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class UploadButton extends StatelessWidget {
  final String currentPath;
  final Function() onUploadComplete;

  const UploadButton({
    Key? key,
    required this.currentPath,
    required this.onUploadComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _selectAndUploadFiles,
      child: Icon(Icons.upload_file),
      tooltip: Intl.uploadFiles.tr,
    );
  }

  Future<void> _selectAndUploadFiles() async {
    if (!await _requestStoragePermission()) {
      Get.snackbar(
        "Permission Denied",
        "Storage permission is required to upload files",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return;

      for (var file in result.files) {
        final filePath = file.path;
        if (filePath == null) continue;

        final fileName = file.name;
        final fileType = FileUtils.getFileType(fileName);

        await _uploadFile(filePath, fileName, fileType);
      }

      onUploadComplete();
    } catch (e) {
      Get.snackbar(
        "Upload Error",
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.storage.isGranted) {
      return true;
    }
    
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<void> _uploadFile(String filePath, String fileName, FileType fileType) async {
    // 这里应该集成到现有的上传逻辑
    // 使用现有的 UploadingFilesController
    final uploadController = Get.find<UploadingFilesController>();
    
    await uploadController.uploadFile(
      localPath: filePath,
      remotePath: currentPath,
      fileName: fileName,
      fileType: fileType,
    );
  }
}

// 增强的上传控制器扩展
extension UploadingFilesControllerExtension on UploadingFilesController {
  Future<void> uploadFile({
    required String localPath,
    required String remotePath,
    required String fileName,
    required FileType fileType,
  }) async {
    // 使用现有的上传逻辑
    final file = File(localPath);
    if (!await file.exists()) return;

    final fileSize = await file.length();
    
    // 添加到上传队列
    final uploadItem = UploadingFile(
      name: fileName,
      path: remotePath,
      size: fileSize,
      fileType: fileType,
    );

    await this.addUploadTask(uploadItem);
  }
}

// 上传文件对话框
class UploadDialog extends StatelessWidget {
  final String currentPath;
  
  const UploadDialog({Key? key, required this.currentPath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(Intl.uploadFiles.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () => _uploadSingleFile(context),
            child: Text("Upload Single File"),
          ),
          ElevatedButton(
            onPressed: () => _uploadMultipleFiles(context),
            child: Text("Upload Multiple Files"),
          ),
          ElevatedButton(
            onPressed: () => _createFolder(context),
            child: Text("Create Folder"),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel"),
        ),
      ],
    );
  }

  void _uploadSingleFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    
    if (result != null && result.files.isNotEmpty) {
      // 处理单个文件上传
      Navigator.pop(context);
    }
  }

  void _uploadMultipleFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    
    if (result != null && result.files.isNotEmpty) {
      // 处理多个文件上传
      Navigator.pop(context);
    }
  }

  void _createFolder(BuildContext context) {
    // 打开创建文件夹对话框
    Navigator.pop(context);
  }
}

// 文件管理菜单
class FileManagementMenu {
  static void showFileManagementMenu(
    BuildContext context,
    FileItemVO file,
    Function(String) onDelete,
    Function(String, String) onRename,
    Function(String, String) onMove,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.delete),
                title: Text("Delete"),
                onTap: () {
                  Navigator.pop(context);
                  onDelete(file.path);
                },
              ),
              ListTile(
                leading: Icon(Icons.edit),
                title: Text("Rename"),
                onTap: () {
                  Navigator.pop(context);
                  onRename(file.path, file.name);
                },
              ),
              ListTile(
                leading: Icon(Icons.move_to_inbox),
                title: Text("Move"),
                onTap: () {
                  Navigator.pop(context);
                  onMove(file.path, file.name);
                },
              ),
              ListTile(
                leading: Icon(Icons.share),
                title: Text("Share"),
                onTap: () {
                  Navigator.pop(context);
                  // Handle share
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// 文件类型图标映射
class FileIconHelper {
  static IconData getIcon(FileType fileType) {
    switch (fileType) {
      case FileType.folder:
        return Icons.folder;
      case FileType.image:
        return Icons.image;
      case FileType.video:
        return Icons.video_library;
      case FileType.audio:
        return Icons.audio_file;
      case FileType.pdf:
        return Icons.picture_as_pdf;
      case FileType.markdown:
        return Icons.description;
      case FileType.txt:
        return Icons.text_snippet;
      case FileType.code:
        return Icons.code;
      case FileType.compress:
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  static Color getColor(FileType fileType) {
    switch (fileType) {
      case FileType.folder:
        return Colors.blue;
      case FileType.image:
        return Colors.purple;
      case FileType.video:
        return Colors.red;
      case FileType.audio:
        return Colors.green;
      case FileType.pdf:
        return Colors.orange;
      case FileType.markdown:
        return Colors.teal;
      case FileType.txt:
        return Colors.grey;
      case FileType.code:
        return Colors.indigo;
      case FileType.compress:
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}
