import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../../../core/providers/app_refresh_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/upload_content_provider.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/aspect_ratio_helper.dart';

class UploadContentScreen extends StatefulWidget {
  const UploadContentScreen({super.key});

  @override
  State<UploadContentScreen> createState() => _UploadContentScreenState();
}

class _UploadContentScreenState extends State<UploadContentScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  final ApiService _api = ApiService();
  bool _isUploading = false;
  bool _isLoadingTagOptions = false;
  List<ProductModel> _eligibleTaggedProducts = const <ProductModel>[];
  XFile? _customVideoThumbnailFile;
  XFile? _customReelThumbnailFile;
  String? _activeVideoSelectionKey;
  String? _activeReelSelectionKey;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _syncReelThumbnailState(UploadContentProvider provider) {
    final currentReelKey = provider.selectedMediaType == 'reel' &&
            provider.selectedFiles.isNotEmpty
        ? provider.selectedFiles.first.path
        : null;

    if (_activeReelSelectionKey == currentReelKey) {
      return;
    }

    _activeReelSelectionKey = currentReelKey;
    _customReelThumbnailFile = null;
  }

  void _syncVideoThumbnailState(UploadContentProvider provider) {
    final currentVideoKey = provider.selectedMediaType == 'video' &&
            provider.selectedFiles.isNotEmpty
        ? provider.selectedFiles.first.path
        : null;

    if (_activeVideoSelectionKey == currentVideoKey) {
      return;
    }

    _activeVideoSelectionKey = currentVideoKey;
    _customVideoThumbnailFile = null;
  }

  Future<void> _pickMedia(
      ImageSource source, UploadContentProvider provider) async {
    final contentType = provider.selectedMediaType;

    try {
      if (contentType == 'photo') {
        final XFile? image = source == ImageSource.gallery
            ? await _pickPhotoFromGalleryWithCloudFallback()
            : await _picker.pickImage(
                source: source,
                maxWidth: 1920,
                maxHeight: 1920,
                imageQuality: 85,
              );
        if (image != null && mounted) {
          final localImagePath = await _ensureLocalImagePath(image);
          if (!mounted) {
            return;
          }
          // Show loading indicator while preparing cropper
          if (kIsWeb) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Preparing image cropper...'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          // Crop the image before adding
          await _cropImage(localImagePath, image, provider);
        }
      } else if (contentType == 'video' || contentType == 'reel') {
        final XFile? video = await _picker.pickVideo(
          source: source,
          maxDuration: contentType == 'reel'
              ? const Duration(seconds: 60)
              : const Duration(minutes: 10),
        );
        if (video != null && mounted) {
          if (contentType == 'reel') {
            final dimensions = await _getVideoDimensions(video);
            if (!mounted) {
              return;
            }
            if (dimensions == null || !_isValidReelAspectRatio(dimensions)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Reels must be vertical 9:16 videos.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
          }
          provider.addFile(video);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${contentType == 'reel' ? 'Reel' : 'Video'} selected successfully!'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else if (contentType == 'audio') {
        // For audio, we'll use a file picker or let user record
        // For now, showing a message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio upload coming soon!')),
          );
        }
      }
    } catch (e) {
      debugPrint('Media Picker Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking media: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<XFile?> _pickPhotoFromGalleryWithCloudFallback() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) return image;
    } catch (_) {
      // Fallback below.
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final selected = result.files.first;
    if (kIsWeb) {
      if (selected.bytes == null || selected.bytes!.isEmpty) {
        return null;
      }
      return XFile.fromData(
        selected.bytes!,
        name: selected.name,
        mimeType: 'image/${_safeImageExtension(selected.name)}',
      );
    }

    if (selected.path != null && selected.path!.isNotEmpty) {
      return XFile(
        selected.path!,
        name: selected.name,
        mimeType: 'image/${_safeImageExtension(selected.name)}',
      );
    }

    if (selected.bytes == null) {
      return null;
    }

    final tempDir = Directory.systemTemp;
    final extension = _safeImageExtension(selected.name);
    final tempPath =
        '${tempDir.path}${Platform.pathSeparator}cloud_upload_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(selected.bytes!, flush: true);
    return XFile(tempFile.path);
  }

  Future<String> _ensureLocalImagePath(XFile file) async {
    if (!kIsWeb) {
      final originalPath = file.path;
      if (originalPath.isNotEmpty && File(originalPath).existsSync()) {
        return originalPath;
      }

      final bytes = await file.readAsBytes();
      final tempDir = Directory.systemTemp;
      final extension = _safeImageExtension(file.name);
      final tempPath =
          '${tempDir.path}${Platform.pathSeparator}upload_${DateTime.now().microsecondsSinceEpoch}.$extension';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes, flush: true);
      return tempFile.path;
    }

    final bytes = await file.readAsBytes();
    final mimeType = 'image/${_safeImageExtension(file.name)}';
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  String _safeImageExtension(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.gif')) return 'gif';
    return 'jpg';
  }

  Future<void> _cropImage(String imagePath, XFile originalImage,
      UploadContentProvider provider) async {
    try {
      final viewportSize = MediaQuery.sizeOf(context);
      final webCropWidth =
          (viewportSize.width * 0.82).clamp(320.0, 560.0).round();
      final webCropHeight =
          (viewportSize.height * 0.62).clamp(320.0, 520.0).round();
      final aspectRatio = AspectRatioHelper.getAspectRatioForType(
        'photo',
        photoRatio: provider.photoAspectRatio,
      );

      // Calculate aspect ratio values
      final ratioX = aspectRatio.ratio >= 1 ? aspectRatio.ratio : 1.0;
      final ratioY = aspectRatio.ratio < 1 ? (1.0 / aspectRatio.ratio) : 1.0;

      if (Platform.isWindows) {
        if (mounted) {
          provider.addFile(originalImage);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image added without cropping on Windows'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        return;
      }

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: CropAspectRatio(
          ratioX: ratioX,
          ratioY: ratioY,
        ),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: _getAndroidAspectRatio(provider.photoAspectRatio),
            lockAspectRatio: true,
            hideBottomControls: false,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            rectHeight: 400,
            rectWidth: 400,
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: CropperSize(
              width: webCropWidth,
              height: webCropHeight,
            ),
          ),
        ],
      );

      if (croppedFile != null) {
        if (mounted) {
          if (kIsWeb) {
            final croppedBytes = await croppedFile.readAsBytes();
            if (!mounted) {
              return;
            }
            provider.addFile(
              XFile.fromData(
                croppedBytes,
                name: 'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
                mimeType: 'image/jpeg',
              ),
            );
          } else {
            provider.addFile(XFile(croppedFile.path));
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image cropped successfully!'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        // User cancelled cropping, use original image
        if (mounted) {
          final shouldUseOriginal = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Use Original Image?'),
              content: const Text(
                  'Cropping was cancelled. Would you like to use the original image instead?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Use Original'),
                ),
              ],
            ),
          );

          if (shouldUseOriginal == true && mounted) {
            provider.addFile(originalImage);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        // Detailed error logging and user-friendly message
        debugPrint('Image Cropper Error: $e');

        final shouldUseOriginal = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cropping Error'),
            content: Text(
              'Unable to crop image: ${e.toString()}\n\nWould you like to use the original image instead?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Use Original'),
              ),
            ],
          ),
        );

        if (shouldUseOriginal == true && mounted) {
          provider.addFile(originalImage);
        }
      }
    }
  }

  CropAspectRatioPreset _getAndroidAspectRatio(String ratio) {
    switch (ratio) {
      case 'square':
        return CropAspectRatioPreset.square;
      case 'portrait':
        return CropAspectRatioPreset.ratio4x3;
      case 'landscape':
        return CropAspectRatioPreset.ratio16x9;
      default:
        return CropAspectRatioPreset.square;
    }
  }

  Future<void> _uploadContent(UploadContentProvider provider) async {
    if (provider.selectedFiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a file to upload')),
        );
      }
      return;
    }

    final contentType = provider.selectedMediaType;
    final title = _titleController.text.trim();
    final caption = _captionController.text.trim();
    if (contentType == 'video' && title.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video title is required')),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final file = provider.selectedFiles.first;
      final appRefresh = context.read<AppRefreshProvider>();

      if (contentType == 'photo') {
        // Use uploadPhoto which saves to user_media and creates a post
        final result = await _api.uploadPhoto(
          imageFile: file,
          caption: caption,
          createPost: true,
        );
        if (result['success'] == true) {
          if (mounted) {
            provider.notifyUploadSuccess();
            provider.clearAll();
            _titleController.clear();
            _captionController.clear();
            _customVideoThumbnailFile = null;
            _customReelThumbnailFile = null;
            _activeVideoSelectionKey = null;
            _activeReelSelectionKey = null;
            appRefresh.notifyContentPublished();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['post_created'] == true
                    ? 'Photo posted successfully!'
                    : 'Photo uploaded successfully!'),
              ),
            );
            context.go('/profile');
          }
        }
      } else if (contentType == 'video') {
        // Upload video and create video record
        final result = await _api.uploadVideo(file, folder: 'videos');
        if (result['url'] != null) {
          final videoUrl = result['url'] as String;
          final description = caption.isEmpty ? title : caption;
          final thumbnailUrl = await _uploadVideoThumbnail(
            file,
            fallbackUrl: videoUrl,
            folder: 'videos-thumbnails',
            customThumbnailFile: _customVideoThumbnailFile,
            promptLabel: 'video',
          );
          final durationMs = await _getVideoDurationMs(file);

          // Create video record
          await _api.createVideo(
            title: title,
            description: description,
            url: videoUrl,
            thumbnail: thumbnailUrl,
            duration: durationMs == null ? null : (durationMs / 1000).round(),
            productIds:
                provider.taggedProducts.map((product) => product.id).toList(),
          );

          if (mounted) {
            provider.clearAll();
            _titleController.clear();
            _captionController.clear();
            _customVideoThumbnailFile = null;
            _customReelThumbnailFile = null;
            _activeVideoSelectionKey = null;
            _activeReelSelectionKey = null;
            appRefresh.notifyContentPublished();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video uploaded successfully!')),
            );
            context.go('/profile');
          }
        }
      } else if (contentType == 'reel') {
        final dimensions = await _getVideoDimensions(file);
        if (dimensions == null || !_isValidReelAspectRatio(dimensions)) {
          throw Exception('Reels must be vertical 9:16 videos');
        }

        // Upload video and create reel record
        final result = await _api.uploadVideo(file, folder: 'reels');
        if (result['url'] != null) {
          final videoUrl = result['url'] as String;
          final thumbnailUrl = await _uploadVideoThumbnail(
            file,
            fallbackUrl: videoUrl,
            folder: 'reels-thumbnails',
            customThumbnailFile: _customReelThumbnailFile,
            promptLabel: 'reel',
          );

          // Create reel record
          await _api.createReel(
            url: videoUrl,
            thumbnail: thumbnailUrl,
            width: dimensions.width.round(),
            height: dimensions.height.round(),
            caption: caption,
            productIds:
                provider.taggedProducts.map((product) => product.id).toList(),
          );

          if (mounted) {
            provider.clearAll();
            _titleController.clear();
            _captionController.clear();
            _customVideoThumbnailFile = null;
            _customReelThumbnailFile = null;
            _activeVideoSelectionKey = null;
            _activeReelSelectionKey = null;
            appRefresh.notifyContentPublished();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reel uploaded successfully!')),
            );
            context.go('/profile');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadContentProvider>(
      builder: (context, provider, child) {
        _syncVideoThumbnailState(provider);
        _syncReelThumbnailState(provider);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Upload Content'),
            actions: [
              if (provider.selectedFiles.isNotEmpty && !_isUploading)
                TextButton(
                  onPressed: () => _uploadContent(provider),
                  child: const Text(
                    'Upload',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Content type selector
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Content Type',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.photo, size: 20),
                                    SizedBox(height: 4),
                                    Text('Photo',
                                        style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                                selected: provider.selectedMediaType == 'photo',
                                onSelected: (selected) {
                                  if (selected) {
                                    provider.setMediaType('photo');
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.videocam, size: 20),
                                    SizedBox(height: 4),
                                    Text('Video',
                                        style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                                selected: provider.selectedMediaType == 'video',
                                onSelected: (selected) {
                                  if (selected) {
                                    provider.setMediaType('video');
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.movie, size: 20),
                                    SizedBox(height: 4),
                                    Text('Reel',
                                        style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                                selected: provider.selectedMediaType == 'reel',
                                onSelected: (selected) {
                                  if (selected) {
                                    provider.setMediaType('reel');
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.audiotrack, size: 20),
                                    SizedBox(height: 4),
                                    Text('Audio',
                                        style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                                selected: provider.selectedMediaType == 'audio',
                                onSelected: (selected) {
                                  if (selected) {
                                    provider.setMediaType('audio');
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Aspect Ratio Selector for Photos
                if (provider.selectedMediaType == 'photo' &&
                    provider.selectedFiles.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.crop,
                                  size: 20,
                                  color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Photo Format',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Choose your photo format (Instagram style)',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _AspectRatioButton(
                                  ratio: 'square',
                                  name: '1:1',
                                  icon: Icons.crop_square,
                                  description: 'Square',
                                  isSelected:
                                      provider.photoAspectRatio == 'square',
                                  onTap: () =>
                                      provider.setPhotoAspectRatio('square'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _AspectRatioButton(
                                  ratio: 'portrait',
                                  name: '4:5',
                                  icon: Icons.crop_portrait,
                                  description: 'Portrait',
                                  isSelected:
                                      provider.photoAspectRatio == 'portrait',
                                  onTap: () =>
                                      provider.setPhotoAspectRatio('portrait'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _AspectRatioButton(
                                  ratio: 'landscape',
                                  name: '16:9',
                                  icon: Icons.crop_landscape,
                                  description: 'Landscape',
                                  isSelected:
                                      provider.photoAspectRatio == 'landscape',
                                  onTap: () =>
                                      provider.setPhotoAspectRatio('landscape'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // Reel Format Info
                if (provider.selectedMediaType == 'reel')
                  Card(
                    color: Colors.purple.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.smartphone, color: Colors.purple.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vertical Video Format (9:16)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Perfect for Instagram Reels & Stories',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.purple.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (provider.selectedMediaType == 'video' ||
                    provider.selectedMediaType == 'reel') ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Builder(
                      builder: (context) {
                        final isReel = provider.selectedMediaType == 'reel';
                        final selectedThumbnail = isReel
                            ? _customReelThumbnailFile
                            : _customVideoThumbnailFile;

                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.image_outlined),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isReel
                                          ? 'Reel Thumbnail'
                                          : 'Video Thumbnail',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: provider.selectedFiles.isEmpty
                                        ? null
                                        : () => _pickCustomVideoThumbnail(
                                              isReel: isReel,
                                            ),
                                    child: Text(
                                      selectedThumbnail == null
                                          ? 'Upload'
                                          : 'Change',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                selectedThumbnail == null
                                    ? 'Optional. If you skip it, we can generate one from the ${isReel ? 'reel' : 'video'} before upload.'
                                    : 'This uploaded image will be used as the ${isReel ? 'reel' : 'video'} thumbnail.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              if (selectedThumbnail != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: isReel ? 86 : 120,
                                        height: isReel ? 120 : 68,
                                        child: _buildImagePreview(
                                          selectedThumbnail,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        selectedThumbnail.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          if (isReel) {
                                            _customReelThumbnailFile = null;
                                          } else {
                                            _customVideoThumbnailFile = null;
                                          }
                                        });
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.sell_outlined),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Tagged Products',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoadingTagOptions
                                    ? null
                                    : () => _showTaggedProductsPicker(provider),
                                child: Text(
                                  provider.taggedProducts.isEmpty
                                      ? 'Add'
                                      : 'Edit',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _taggingHint(context),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          if (_isLoadingTagOptions) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(),
                          ],
                          if (provider.taggedProducts.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: provider.taggedProducts
                                  .map(
                                    (product) => Chip(
                                      label: Text(product.title),
                                      onDeleted: () {
                                        final nextProducts =
                                            List<ProductModel>.from(
                                                provider.taggedProducts)
                                              ..removeWhere((item) =>
                                                  item.id == product.id);
                                        provider
                                            .setTaggedProducts(nextProducts);
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                // Video Format Info
                if (provider.selectedMediaType == 'video')
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.video_library,
                              color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Landscape Video Format (16:9)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Standard widescreen format for longer videos',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Preview area
                if (provider.selectedFiles.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Preview',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  // Show aspect ratio for photos
                                  if (provider.selectedMediaType == 'photo')
                                    Chip(
                                      label: Text(
                                        AspectRatioHelper
                                            .photoAspectRatios[
                                                provider.photoAspectRatio]!
                                            .name,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      provider.removeFile(0);
                                      setState(() {
                                        _customVideoThumbnailFile = null;
                                        _customReelThumbnailFile = null;
                                        _activeVideoSelectionKey = null;
                                        _activeReelSelectionKey = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Show preview with correct aspect ratio
                          Center(
                            child: _buildPreview(provider),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.selectedFiles.first.path
                                .split('/')
                                .last
                                .split('\\')
                                .last,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Upload buttons
                  Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            _pickMedia(ImageSource.gallery, provider),
                        icon: const Icon(Icons.photo_library),
                        label: Text(
                          provider.selectedMediaType == 'photo'
                              ? 'Choose from Gallery'
                              : 'Choose Video',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _pickMedia(ImageSource.camera, provider),
                        icon: Icon(
                          provider.selectedMediaType == 'photo'
                              ? Icons.camera_alt
                              : Icons.videocam,
                        ),
                        label: Text(
                          provider.selectedMediaType == 'photo'
                              ? 'Take Photo'
                              : 'Record Video',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                if (provider.selectedMediaType == 'video') ...[
                  TextField(
                    controller: _titleController,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Add a title for this video',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Caption input
                TextField(
                  controller: _captionController,
                  onChanged: provider.setCaption,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: provider.selectedMediaType == 'video'
                        ? 'Description (Optional)'
                        : 'Caption (Optional)',
                    hintText: provider.selectedMediaType == 'video'
                        ? 'Write a description for your video...'
                        : 'Write a caption for your post...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 20),

                // Upload button (main)
                if (provider.selectedFiles.isNotEmpty)
                  ElevatedButton(
                    onPressed:
                        _isUploading ? null : () => _uploadContent(provider),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Upload Content',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreview(UploadContentProvider provider) {
    final aspectRatio = AspectRatioHelper.getAspectRatioForType(
      provider.selectedMediaType,
      photoRatio: provider.photoAspectRatio,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: aspectRatio.ratio,
        child: provider.selectedMediaType == 'photo'
            ? _buildImagePreview(provider.selectedFiles.first)
            : Container(
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.play_circle_outline,
                      size: 64,
                      color: Colors.white,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Chip(
                        label: Text(
                          aspectRatio.name,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white),
                        ),
                        backgroundColor: Colors.black54,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Build image preview that works on both web and mobile
  Widget _buildImagePreview(XFile file) {
    if (kIsWeb) {
      // On web, XFile.path is a blob URL - use Image.network to load it
      return Image.network(
        file.path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Image.memory(snapshot.data!, fit: BoxFit.cover);
              }
              return const Center(child: CircularProgressIndicator());
            },
          );
        },
      );
    } else {
      // On mobile, use File from dart:io
      return Image.file(
        File(file.path),
        fit: BoxFit.cover,
      );
    }
  }

  String _taggingHint(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    if (user?.isSeller == true) {
      return 'Sellers can tag products from their own listings.';
    }
    return 'Consumers can tag products from their purchases.';
  }

  Future<void> _showTaggedProductsPicker(UploadContentProvider provider) async {
    final options = await _loadEligibleTaggedProducts();
    if (!mounted) {
      return;
    }

    final selectedIds =
        provider.taggedProducts.map((product) => product.id).toSet();
    final workingSelection = <String>{...selectedIds};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tag Products',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _taggingHint(context),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    if (options.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No eligible products found yet.'),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final product = options[index];
                            final isSelected =
                                workingSelection.contains(product.id);
                            return CheckboxListTile(
                              value: isSelected,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(product.title),
                              subtitle:
                                  Text('\$${product.price.toStringAsFixed(2)}'),
                              onChanged: (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    workingSelection.add(product.id);
                                  } else {
                                    workingSelection.remove(product.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          provider.setTaggedProducts(
                            options
                                .where((product) =>
                                    workingSelection.contains(product.id))
                                .toList(),
                          );
                          Navigator.of(context).pop();
                        },
                        child: const Text('Save Tagged Products'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<ProductModel>> _loadEligibleTaggedProducts() async {
    if (_eligibleTaggedProducts.isNotEmpty) {
      return _eligibleTaggedProducts;
    }

    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return const <ProductModel>[];
    }

    setState(() => _isLoadingTagOptions = true);
    try {
      final products = user.isSeller
          ? await _api.getSellerProducts(user.id)
          : await _api.getUserPurchases(user.id);
      _eligibleTaggedProducts = products;
      return products;
    } finally {
      if (mounted) {
        setState(() => _isLoadingTagOptions = false);
      }
    }
  }

  Future<Size?> _getVideoDimensions(XFile file) async {
    VideoPlayerController? controller;
    try {
      controller = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(file.path))
          : VideoPlayerController.file(File(file.path));
      await controller.initialize();
      return controller.value.size;
    } catch (_) {
      return null;
    } finally {
      await controller?.dispose();
    }
  }

  bool _isValidReelAspectRatio(Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return false;
    }
    if (size.height <= size.width) {
      return false;
    }

    const targetRatio = 9 / 16;
    final actualRatio = size.width / size.height;
    return (actualRatio - targetRatio).abs() <= 0.03;
  }

  Future<String> _uploadVideoThumbnail(
    XFile videoFile, {
    required String fallbackUrl,
    required String folder,
    required String promptLabel,
    XFile? customThumbnailFile,
  }) async {
    XFile? thumbnailFile = customThumbnailFile;
    if (thumbnailFile == null) {
      final shouldGenerate =
          await _confirmGeneratedThumbnail(promptLabel: promptLabel);
      if (!shouldGenerate) {
        return fallbackUrl;
      }
      thumbnailFile = await _createVideoThumbnailFile(videoFile);
    }
    if (thumbnailFile == null) {
      return fallbackUrl;
    }

    try {
      final uploadResult = await _api.uploadImage(
        thumbnailFile,
        folder: folder,
      );
      final uploadedUrl = (uploadResult['url'] as String?)?.trim();
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        return uploadedUrl;
      }
    } catch (_) {
      // Fall back to the video URL if thumbnail upload fails.
    }

    return fallbackUrl;
  }

  Future<bool> _confirmGeneratedThumbnail({required String promptLabel}) async {
    if (!mounted) {
      return false;
    }

    final shouldGenerate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Thumbnail?'),
        content: Text(
          'No custom thumbnail was uploaded for this $promptLabel. Generate one from the video now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    return shouldGenerate ?? true;
  }

  Future<XFile?> _createVideoThumbnailFile(XFile videoFile) async {
    if (kIsWeb) {
      return null;
    }

    try {
      final durationMs = await _getVideoDurationMs(videoFile);
      final thumbnailBytes = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        quality: 72,
        maxWidth: 720,
        timeMs: _randomThumbnailTimeMs(durationMs),
      );
      if (thumbnailBytes == null || thumbnailBytes.isEmpty) {
        return null;
      }

      return XFile.fromData(
        thumbnailBytes,
        name: 'video_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
        mimeType: 'image/jpeg',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickCustomVideoThumbnail({required bool isReel}) async {
    final picked = await showModalBottomSheet<XFile>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final image = await _pickPhotoFromGalleryWithCloudFallback();
                  if (!navigator.mounted) {
                    return;
                  }
                  navigator.pop(image);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take photo'),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final image = await _picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1440,
                    maxHeight: 2560,
                    imageQuality: 85,
                  );
                  if (!navigator.mounted) {
                    return;
                  }
                  navigator.pop(image);
                },
              ),
            ],
          ),
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isReel) {
        _customReelThumbnailFile = picked;
      } else {
        _customVideoThumbnailFile = picked;
      }
    });
  }

  Future<int?> _getVideoDurationMs(XFile file) async {
    VideoPlayerController? controller;
    try {
      controller = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(file.path))
          : VideoPlayerController.file(File(file.path));
      await controller.initialize();
      return controller.value.duration.inMilliseconds;
    } catch (_) {
      return null;
    } finally {
      await controller?.dispose();
    }
  }

  int _randomThumbnailTimeMs(int? durationMs) {
    final usableDuration = durationMs ?? 0;
    if (usableDuration <= 1500) {
      return 0;
    }

    final minMs = (usableDuration * 0.15).round();
    final maxMs = (usableDuration * 0.75).round();
    if (maxMs <= minMs) {
      return minMs;
    }

    return minMs + math.Random().nextInt(maxMs - minMs);
  }
}

// Aspect Ratio Selection Button Widget
class _AspectRatioButton extends StatelessWidget {
  final String ratio;
  final String name;
  final IconData icon;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _AspectRatioButton({
    required this.ratio,
    required this.name,
    required this.icon,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                fontSize: 9,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
