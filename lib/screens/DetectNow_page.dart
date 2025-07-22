import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:grad/screens/Locator_page.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/Provider/auth_provider.dart';
import '../config/Provider/language_provider.dart';
import 'Main_page.dart';

class DetectNow_page extends StatefulWidget {
  static const String id = 'DetectNow_page';

  final String detectedDisease;
  final Map<String, String?> userInputs;
  final File? uploadedImage;
  final String? annotatedImageBase64;

  const DetectNow_page({
    super.key,
    required this.detectedDisease,
    required this.userInputs,
    required this.uploadedImage,
    required this.annotatedImageBase64,
  });

  @override
  State<DetectNow_page> createState() => _DetectNowPageState();
}

class _DetectNowPageState extends State<DetectNow_page> {
  String? responseText;
  bool isLoading = true;
  late AuthProvider authProvider;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      authProvider = Provider.of<AuthProvider>(context, listen: false);
      final lan = Provider.of<LanguageProvider>(context, listen: false);
      _fetchReportFromGPT(lan);
    });
  }

  String _cleanArabicText(String text) {
    return text.replaceAll(
      RegExp(
        r'[^\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF\s،؛؟]',
      ),
      '',
    );
  }

  Future<void> _fetchReportFromGPT(LanguageProvider lan) async {
    const apiKey =
        'ADD UR API';
    final Uri url = Uri.parse('https://api.openai.com/v1/chat/completions');

    String languageInstruction =
    lan.defLan == 1
        ? 'Respond in English using professional medical terminology. Use clear section titles. Avoid markdown formatting. Do NOT include the phrase "detection report" at the beginning.'
        : '''الرد باللغة العربية الفصحى فقط باستخدام المصطلحات الطبية الدقيقة.
استخدم عناوين واضحة للأقسام.
تجنب تماماً استخدام أي رموز أو تنسيقات غير معتادة.
أكتب النص العربي بشكل واضح دون أي تشوهات.''';

    final prompt = '''
Patient Diagnosis Report Request:
- Detected Condition: ${widget.detectedDisease}
- Symptoms: ${widget.userInputs['symptom']}
- Duration: ${widget.userInputs['duration']}
- Itchiness: ${widget.userInputs['itchiness']}
- Pain Level: ${widget.userInputs['painLevel']}
- Progression: ${widget.userInputs['progress']}
- Skin Type: ${authProvider.userDetails?.skinType}
- Allergies:${authProvider.userDetails?.allergies}

$languageInstruction

Provide a professional dermatological consultation covering:
1. Condition explanation
2. Recommended treatment plan (categorized by urgency)
3. Important precautions
''';

    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3, // Lower for more consistent results
          'max_tokens': 2000,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        String result = data['choices'][0]['message']['content'];

        if (lan.defLan != 1) {
          result = _cleanArabicText(result);
        }

        // Save to history
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.saveDetectionHistory(
          disease: widget.detectedDisease,
          description: result,
          userInputs: widget.userInputs,
          imageBase64: widget.annotatedImageBase64,
        );

        setState(() {
          responseText = result;
          isLoading = false;
        });
      } else {
        setState(() {
          responseText = 'Error: ${res.statusCode} - ${res.reasonPhrase}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        responseText = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    var lan = Provider.of<LanguageProvider>(context, listen: true);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "${widget.detectedDisease[0].toUpperCase()}${widget.detectedDisease.substring(1)} ${lan.getTexts("Detected")}",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Color(0xFF8E97FD),
        foregroundColor: Colors.white,
      ),
      body:
      isLoading
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(0xFF8E97FD),
              ),
            ),
            SizedBox(), // Properly placed SizedBox
            Text(
              lan.getTexts("waitText"),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.annotatedImageBase64 != null &&
                widget.annotatedImageBase64!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(
                  base64Decode(widget.annotatedImageBase64!),
                  height: 350,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Text(
                lan.getTexts("No annotated image available"),
                style: TextStyle(color: Colors.red),
              ),
            SizedBox(height: 20),
            Text(
              responseText ?? lan.getTexts("No data available"),
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.black87,
                fontFamily: lan.defLan == 1 ? 'Roboto' : 'Tajawal',
              ),
              textDirection:
              lan.defLan == 1
                  ? TextDirection.ltr
                  : TextDirection.rtl,
            ),
            SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LocatorPage(showBackButton: true,))
                  );
                },
                icon: Icon(Icons.place, color: Colors.white),
                label: Text(
                  lan.getTexts("findNearestButton"),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF8E97FD),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            ),
            SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MainPage())
                  );
                },
                label: Text(
                  lan.getTexts("Done"),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF8E97FD),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            ),
          ],
        ),
      ),
    );
  }
}
