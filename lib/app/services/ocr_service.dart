import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer;

  OcrService()
      : _textRecognizer = TextRecognizer(script: TextRecognitionScript.japanese);

  Future<String> processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      print("OCR Service Error: $e");
      return "";
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}