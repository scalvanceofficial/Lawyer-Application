import 'dart:convert';

import 'package:aapkelawyer/services/legal_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('LegalAiService.isLegalQuery', () {
    test('accepts clear legal questions', () {
      expect(
        LegalAiService.isLegalQuery('How can I apply for bail after an FIR?'),
        isTrue,
      );
      expect(
        LegalAiService.isLegalQuery('What are my rights under this contract?'),
        isTrue,
      );
      expect(
        LegalAiService.isLegalQuery(
          'What is the difference between plaintiff and defendant?',
        ),
        isTrue,
      );
    });

    test('rejects unrelated questions without legal context', () {
      expect(LegalAiService.isLegalQuery('Give me a pasta recipe'), isFalse);
      expect(LegalAiService.isLegalQuery('Will it rain tomorrow?'), isFalse);
    });

    test('allows meaningful follow-up questions in legal context', () {
      expect(
        LegalAiService.isLegalQuery(
          'What should I do next?',
          hasLegalContext: true,
        ),
        isTrue,
      );
    });
  });

  group('LegalAiService OpenAI response handling', () {
    const configuration = LegalAiConfiguration(
      apiKey: 'test-key-not-a-secret',
      textModel: 'test-text-model',
      imageModel: 'gpt-image-1',
    );

    test('returns actual document content from the Responses API', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/responses');
        expect(
          request.headers['Authorization'],
          'Bearer test-key-not-a-secret',
        );
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['model'], 'test-text-model');
        return http.Response(
          jsonEncode({
            'output': [
              {
                'type': 'message',
                'content': [
                  {
                    'type': 'output_text',
                    'text': '[DOCUMENT_READY]\n# RENT AGREEMENT\n\nSIGNATURES:',
                  },
                ],
              },
            ],
          }),
          200,
        );
      });
      final service = LegalAiService(
        engine: LegalAiEngine.documentGenerator,
        client: client,
        configurationLoader: () async => configuration,
      );

      final answer = await service.send('Generate a rent agreement PDF');

      expect(answer, contains('[DOCUMENT_READY]'));
      expect(answer, contains('RENT AGREEMENT'));
    });

    test('decodes base64 image bytes from the Images API', () async {
      final expectedBytes = [137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3];
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/images/generations');
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['model'], 'gpt-image-1');
        expect(requestBody['output_format'], 'png');
        return http.Response(
          jsonEncode({
            'data': [
              {'b64_json': base64Encode(expectedBytes)},
            ],
          }),
          200,
        );
      });
      final service = LegalAiService(
        client: client,
        configurationLoader: () async => configuration,
      );

      final image = await service.generateImage('Create an image of a court');

      expect(image.bytes, expectedBytes);
    });

    test('rejects an unsupported image response', () async {
      final service = LegalAiService(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'data': []}), 200),
        ),
        configurationLoader: () async => configuration,
      );

      expect(
        () => service.generateImage('Create an image of a court'),
        throwsA(isA<LegalAiException>()),
      );
    });
  });
}
