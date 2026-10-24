import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

enum LegalAiEngine { caseAnalyzer, strategy, documentGenerator, caseResearch }

extension LegalAiEngineDetails on LegalAiEngine {
  String get title => switch (this) {
    LegalAiEngine.caseAnalyzer => 'Case Analyzer',
    LegalAiEngine.strategy => 'Legal Strategy',
    LegalAiEngine.documentGenerator => 'Document Generator',
    LegalAiEngine.caseResearch => 'Case Research',
  };

  String get description => switch (this) {
    LegalAiEngine.caseAnalyzer =>
      'Turn your story into legal issues, evidence, risks, and next steps.',
    LegalAiEngine.strategy =>
      'Build a practical action, negotiation, and litigation strategy.',
    LegalAiEngine.documentGenerator =>
      'Create a guided first draft of notices, complaints, agreements, and more.',
    LegalAiEngine.caseResearch =>
      'Understand relevant laws, principles, and verified legal authorities.',
  };

  String get greeting => switch (this) {
    LegalAiEngine.caseAnalyzer =>
      'Tell me what happened in your own words. Include where it happened and what outcome you want, if you know.',
    LegalAiEngine.strategy =>
      'Briefly describe the legal issue and your current position. I’ll help organize immediate priorities and options.',
    LegalAiEngine.documentGenerator =>
      'What document would you like to prepare? For example: a legal notice, police complaint, RTI, agreement, or reply.',
    LegalAiEngine.caseResearch =>
      'What legal topic or issue would you like to research? Add the State and court level if they matter.',
  };

  String get inputHint => switch (this) {
    LegalAiEngine.caseAnalyzer => 'Explain what happened…',
    LegalAiEngine.strategy => 'Describe your issue and goal…',
    LegalAiEngine.documentGenerator => 'Name the document you need…',
    LegalAiEngine.caseResearch => 'Enter a legal topic or question…',
  };
}

class LegalAiService {
  LegalAiService({
    this.engine = LegalAiEngine.caseAnalyzer,
    http.Client? client,
    Future<LegalAiConfiguration> Function()? configurationLoader,
  }) : _client = client ?? http.Client(),
       _configurationLoader = configurationLoader;

  final LegalAiEngine engine;
  final http.Client _client;
  final Future<LegalAiConfiguration> Function()? _configurationLoader;
  final List<Map<String, dynamic>> _history = [];

  static const _defaultModel = 'gpt-4.1-mini';
  static final Uri _responsesUri = Uri.parse(
    'https://api.openai.com/v1/responses',
  );
  static final Uri _imagesUri = Uri.parse(
    'https://api.openai.com/v1/images/generations',
  );
  static const _requestTimeout = Duration(seconds: 90);

  static const _baseInstruction =
      'You are NyaySaarthi, a legal information assistant. '
      'Answer only legal or closely related procedural questions. '
      'Use plain language, short paragraphs, and numbered steps where helpful. '
      'Ask for the country/state when jurisdiction matters. Never claim to be '
      'the user’s advocate, never guarantee outcomes, and clearly distinguish '
      'general legal information from advice. For urgent arrest, violence, '
      'self-harm, or immediate danger, tell the user to contact appropriate '
      'local emergency services or a qualified advocate immediately. Do not '
      'invent statutes, cases, citations, deadlines, or court procedures. If '
      'uncertain, say so and recommend verification with a qualified advocate. '
      'Do not encourage illegal activity, fabricated evidence, evasion of law '
      'enforcement, harassment, threats, or fraudulent documents. Remember '
      'facts already provided in this conversation and do not ask for them again. '
      'Ask only essential follow-up questions, one small group at a time. '
      'Always end substantive output with a concise general-information disclaimer.';

  String get _systemInstruction =>
      '$_baseInstruction ${switch (engine) {
        LegalAiEngine.caseAnalyzer => 'You are the Case Analyzer engine. Progressively collect parties, timeline, location, money, documents, witnesses, police involvement, current status, urgency, and desired outcome. Do not overwhelm the user. When enough facts exist, structure the response under: Case Summary; Case Category; Possible Applicable Laws (only when reasonably supported); Important Legal Concepts; Required Documents (Already Available, Need To Collect, Recommended); Evidence Strength; Possible Risks; Suggested Next Steps; Approximate Timeline; Estimated Litigation Stages; Suggested Advocate Type. Never state certainty.',
        LegalAiEngine.strategy => 'You are the Legal Strategy engine. The user already knows the issue. Structure substantive advice under: Risk Level; Immediate Action Checklist; Critical Mistakes To Avoid; Evidence To Preserve; Negotiation Strategy; Litigation Strategy; Alternative Remedies; Expected Timeline; Documents Needed; Practical Tips; Questions To Ask An Advocate. Never guarantee victory or predict a court decision.',
        LegalAiEngine.documentGenerator => 'You are the Legal Document Generator engine. First identify the requested document, then progressively collect only necessary names, addresses, dates, amounts, facts, jurisdiction, and desired relief. Do not ask everything together. Once sufficient details exist, produce the complete editable, professionally formatted, PDF-ready draft in the response with headings and a signature section. Then explain Purpose; When To Use; Where To File or Send; Who Signs; Supporting Documents. Clearly mark unknown values with editable square-bracket placeholders. Put [DOCUMENT_READY] on its own first line only when the response contains the complete document draft and is ready for local PDF creation. Do not use that marker while asking follow-up questions. Never claim that you created, attached, uploaded, saved, or linked a file, and never output sandbox links or fake download URLs. The app creates the actual PDF from your response. If asked to generate or download a PDF, repeat the complete final draft so the app can export it. Never create a fraudulent or misleading document.',
        LegalAiEngine.caseResearch => 'You are the Case Research engine for Indian law. Explain, do not merely list. Structure results under: Relevant Statutes; Relevant Provisions; Supreme Court Authorities; High Court Authorities; Important Principles; Plain-Language Explanation; Arguments Often Accepted; Arguments Often Rejected; Common Mistakes; Recent Legal Developments. Never fabricate an authority, citation, case number, date, or holding. When an authority cannot be identified confidently, explicitly say: "I couldn’t confidently identify a relevant authority." Distinguish verified knowledge from points that need current database verification.',
      }}';

  static final RegExp _legalTerms = RegExp(
    r'\b('
    r'law|legal|lawyer|advocate|attorney|court|judge|judgment|petition|'
    r'appeal|case|lawsuit|litigation|notice|summons|warrant|contract|'
    r'agreement|clause|breach|rights?|crime|criminal|civil|police|fir|'
    r'bail|arrest|custody|divorce|marriage|maintenance|alimony|domestic '
    r'violence|property|tenant|landlord|rent|lease|inheritance|succession|'
    r'will and testament|probate|consumer|fraud|cheating|cybercrime|harassment|defamation|'
    r'copyright|trademark|patent|company|employment|labour|labor|salary|'
    r'tax|gst|ipc|crpc|bnss|bns|evidence act|constitution|supreme court|'
    r'high court|district court|tribunal|affidavit|notary|registration|'
    r'compensation|damages|injunction|limitation|mediation|arbitration|'
    r'plaintiff|defendant|jurisdiction|tort|precedent|statute|negligence|'
    r'liability|settlement|pleading|discovery|motion|verdict|sentencing|'
    r'deposition|hearing|probation|parole|pardon|acquittal|conviction|'
    r'magistrate|prosecutor|legal aid|charge sheet|cpc|indian penal code|'
    r'indian contract act|companies act|consumer protection act|factories act|'
    r'transfer of property act|power of attorney|sale deed|lease agreement|'
    r'divorce petition|child custody|court order|legal notice|dowry|adoption|'
    r'fiduciary duty|professional misconduct|legal malpractice|income tax|'
    r'corporate governance|data protection|compliance|constitutional law|'
    r'administrative law|family law|corporate law|tax law|immigration law|'
    r'environmental law|real estate|international law|cyber law|due process|'
    r'indemnity|force majeure|non-disclosure agreement|nda|mou|memorandum of '
    r'understanding|terms and conditions|indemnification|burden of proof|'
    r'plea bargain|legal counsel|specific performance|class action|legal brief'
    r')\b',
    caseSensitive: false,
  );

  static bool isLegalQuery(String text, {bool hasLegalContext = false}) {
    final normalized = text.trim();
    if (normalized.length < 3) return false;
    return _legalTerms.hasMatch(normalized) ||
        (hasLegalContext && normalized.split(RegExp(r'\s+')).length >= 2);
  }

  Future<String> send(String message) async {
    try {
      final configuration = await _loadConfiguration();
      final apiKey = configuration.apiKey;
      final model = configuration.textModel;

      final userContent = {'role': 'user', 'content': message.trim()};
      late http.Response response;
      for (var attempt = 0; attempt < 3; attempt++) {
        response = await _client
            .post(
              _responsesUri,
              headers: _headers(apiKey),
              body: jsonEncode({
                'model': model,
                'instructions': _systemInstruction,
                'input': [..._history, userContent],
              }),
            )
            .timeout(_requestTimeout);
        if (response.statusCode != 429 || attempt == 2) break;
        await Future<void>.delayed(Duration(seconds: 1 << (attempt + 1)));
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        final apiMessage =
            ((payload['error'] as Map?)?['message'] ?? 'Unknown OpenAI error')
                .toString();
        final safeApiMessage = _redactSecrets(apiMessage, apiKey);
        final explanation = switch (response.statusCode) {
          400 => 'OpenAI rejected the request: $safeApiMessage',
          401 =>
            'OpenAI rejected the API key. Check the openaikey value in '
                'Firestore. Details: $safeApiMessage',
          403 =>
            'OpenAI denied access to this request. Check the API key project '
                'permissions and model access. Details: $safeApiMessage',
          404 => 'The OpenAI model "$model" is unavailable: $safeApiMessage',
          429 =>
            'The OpenAI rate limit or usage quota was reached. Please try '
                'again later.',
          _ => 'OpenAI returned error ${response.statusCode}: $safeApiMessage',
        };
        throw LegalAiException(explanation);
      }

      final output = payload['output'] as List?;
      final text = output
          ?.whereType<Map>()
          .where((item) => item['type'] == 'message')
          .expand((item) => (item['content'] as List?) ?? const [])
          .whereType<Map>()
          .where((part) => part['type'] == 'output_text')
          .map((part) => part['text']?.toString() ?? '')
          .join()
          .trim();
      if (text == null || text.isEmpty) {
        throw const LegalAiException(
          'NyaySaarthi returned an empty answer. Please ask again.',
        );
      }
      _history
        ..add(userContent)
        ..add({'role': 'assistant', 'content': text});
      return _format(text);
    } on LegalAiException {
      rethrow;
    } on TimeoutException {
      throw const LegalAiException(
        'NyaySaarthi timed out while generating the response. Please try again.',
      );
    } on FirebaseException catch (error) {
      throw LegalAiException(
        error.code == 'permission-denied'
            ? 'Firestore denied access to usefulkey. Deploy the updated '
                  'Firestore rules and try again.'
            : 'Could not read the NyaySaarthi configuration: ${error.message ?? error.code}',
      );
    } on FormatException {
      throw const LegalAiException(
        'OpenAI returned an unreadable response. Please try again.',
      );
    } catch (_) {
      throw const LegalAiException(
        'Could not reach OpenAI. Check your internet connection and try again.',
      );
    }
  }

  Future<GeneratedImageData> generateImage(String prompt) async {
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.isEmpty) {
      throw const LegalAiException('Please describe the image you need.');
    }
    try {
      final configuration = await _loadConfiguration();
      final response = await _client
          .post(
            _imagesUri,
            headers: _headers(configuration.apiKey),
            body: jsonEncode({
              'model': configuration.imageModel,
              'prompt': normalizedPrompt,
              'size': '1024x1024',
              'quality': 'medium',
              'output_format': 'png',
            }),
          )
          .timeout(const Duration(minutes: 2));
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        final apiMessage =
            ((payload['error'] as Map?)?['message'] ?? 'Unknown OpenAI error')
                .toString();
        throw LegalAiException(
          'OpenAI image generation failed: '
          '${_redactSecrets(apiMessage, configuration.apiKey)}',
        );
      }
      final data = payload['data'];
      if (data is! List || data.isEmpty || data.first is! Map) {
        throw const LegalAiException(
          'OpenAI returned an unsupported image response.',
        );
      }
      final image = Map<String, dynamic>.from(data.first as Map);
      final encoded = image['b64_json']?.toString();
      if (encoded == null || encoded.isEmpty) {
        throw const LegalAiException(
          'OpenAI did not return image data in a supported format.',
        );
      }
      late Uint8List bytes;
      try {
        bytes = base64Decode(encoded);
      } on FormatException {
        throw const LegalAiException(
          'OpenAI returned invalid image data. Please try again.',
        );
      }
      const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
      if (bytes.length < pngSignature.length ||
          !List.generate(
            pngSignature.length,
            (index) => bytes[index] == pngSignature[index],
          ).every((matches) => matches)) {
        throw const LegalAiException(
          'OpenAI returned image data in an unsupported format.',
        );
      }
      return GeneratedImageData(
        bytes: bytes,
        revisedPrompt: image['revised_prompt']?.toString(),
      );
    } on LegalAiException {
      rethrow;
    } on TimeoutException {
      throw const LegalAiException(
        'Image generation timed out. Please try again.',
      );
    } on FirebaseException catch (error) {
      throw LegalAiException(
        'Could not read the NyaySaarthi configuration: '
        '${error.message ?? error.code}',
      );
    } on FormatException {
      throw const LegalAiException(
        'OpenAI returned an unreadable image response.',
      );
    } catch (_) {
      throw const LegalAiException(
        'Unable to generate the image. Check your connection and try again.',
      );
    }
  }

  // TODO(security): Move OpenAI calls behind a trusted backend/serverless
  // function before production. A mobile app API key can always be extracted.
  Future<LegalAiConfiguration> _loadConfiguration() =>
      _configurationLoader?.call() ?? _configuration();

  static Future<LegalAiConfiguration> _configuration() async {
    final keySnapshot = await FirebaseFirestore.instance
        .collection('usefulkey')
        .limit(1)
        .get();
    if (keySnapshot.docs.isEmpty) {
      throw const LegalAiException(
        'NyaySaarthi is not configured. Add an openaikey field to the usefulkey collection.',
      );
    }
    final data = keySnapshot.docs.first.data();
    final apiKey = (data['openaikey'] ?? '').toString().trim();
    if (apiKey.isEmpty) {
      throw const LegalAiException(
        'The openaikey field in Firestore is empty.',
      );
    }
    final configuredModel = (data['model'] ?? '').toString().trim();
    final textModel =
        configuredModel.isEmpty ||
            configuredModel.toLowerCase().startsWith('gemini')
        ? _defaultModel
        : configuredModel;
    final configuredImageModel = (data['imageModel'] ?? '').toString().trim();
    return LegalAiConfiguration(
      apiKey: apiKey,
      textModel: textModel,
      imageModel: configuredImageModel.isEmpty
          ? 'gpt-image-1'
          : configuredImageModel,
    );
  }

  static Map<String, String> _headers(String apiKey) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  static String _format(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^\s*[\*\-]\s+', multiLine: true), '• ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _redactSecrets(String message, String apiKey) {
    var safe = message.replaceAll(apiKey, '[API key hidden]');
    safe = safe.replaceAll(
      RegExp(r'AIza[0-9A-Za-z_-]{20,}'),
      '[API key hidden]',
    );
    safe = safe.replaceAll(
      RegExp(r'sk-[0-9A-Za-z_-]{20,}'),
      '[API key hidden]',
    );
    return safe;
  }
}

class GeneratedImageData {
  const GeneratedImageData({required this.bytes, this.revisedPrompt});
  final Uint8List bytes;
  final String? revisedPrompt;
}

class LegalAiConfiguration {
  const LegalAiConfiguration({
    required this.apiKey,
    required this.textModel,
    required this.imageModel,
  });

  final String apiKey;
  final String textModel;
  final String imageModel;
}

class LegalAiException implements Exception {
  const LegalAiException(this.message);
  final String message;
}
