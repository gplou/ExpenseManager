import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Thin abstraction over `package:image_picker` so the camera/gallery
/// flow can be tested without the platform plugin.
abstract interface class ImageInputGateway {
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  });
}

class ImagePickerGateway implements ImageInputGateway {
  ImagePickerGateway() : _picker = ImagePicker();
  final ImagePicker _picker;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) {
    return _picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }
}

final imageInputGatewayProvider = Provider<ImageInputGateway>((ref) {
  return ImagePickerGateway();
});
