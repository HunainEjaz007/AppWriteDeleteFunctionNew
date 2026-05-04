import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';

void main() {
  runApp(const DebugApp());
}

class DebugApp extends StatelessWidget {
  const DebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Appwrite Debug Runner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A6E4F)),
      ),
      home: const DebugHomePage(),
    );
  }
}

class DebugHomePage extends StatefulWidget {
  const DebugHomePage({super.key});

  @override
  State<DebugHomePage> createState() => _DebugHomePageState();
}

class _DebugHomePageState extends State<DebugHomePage> {
  final TextEditingController _selectedCollectionsController =
      TextEditingController(text: 'ai_content');

  bool _isLoading = false;
  String _result = 'No execution yet.';

  @override
  void dispose() {
    _selectedCollectionsController.dispose();
    super.dispose();
  }

  Future<void> _runDeleteAll() async {
    await _execute(
      functionId: AppConfig.deleteAllFunctionId,
      payload: null,
      mode: 'delete_all_collections',
    );
  }

  Future<void> _runDeleteSelected() async {
    final ids = _selectedCollectionsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    if (ids.isEmpty) {
      setState(() {
        _result = 'Please provide at least one collection id.';
      });
      return;
    }

    await _execute(
      functionId: AppConfig.deleteSelectedFunctionId,
      payload: <String, Object?>{'collectionIds': ids},
      mode: 'delete_selected_collections',
    );
  }

  Future<void> _execute({
    required String functionId,
    required String mode,
    Map<String, Object?>? payload,
  }) async {
    setState(() {
      _isLoading = true;
      _result = 'Running $mode...';
    });

    final raw = AppConfig.endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    final endpoint = raw.endsWith('/v1') ? raw : '$raw/v1';
    final uri = Uri.parse('$endpoint/functions/$functionId/executions');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Appwrite-Project': AppConfig.projectId,
      'X-Appwrite-Key': AppConfig.apiKey,
    };

    try {
      final requestBody = <String, Object?>{
        'async': false,
        'body': payload == null ? '{}' : jsonEncode(payload),
      };

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      Object? parsedBody;
      try {
        parsedBody = jsonDecode(response.body);
      } catch (_) {
        parsedBody = response.body;
      }

      final executionResponseBody = parsedBody is Map<String, dynamic>
          ? parsedBody['responseBody']
          : null;

      Object? decodedExecutionBody = executionResponseBody;
      if (executionResponseBody is String && executionResponseBody.trim().isNotEmpty) {
        try {
          decodedExecutionBody = jsonDecode(executionResponseBody);
        } catch (_) {
          decodedExecutionBody = executionResponseBody;
        }
      }

      final output = <String, Object?>{
        'mode': mode,
        'functionId': functionId,
        'request': <String, Object?>{
          'url': uri.toString(),
          'payload': payload,
          'createExecutionBody': requestBody,
        },
        'httpStatus': response.statusCode,
        'response': parsedBody,
        'executionResponseBodyDecoded': decodedExecutionBody,
      };

      setState(() {
        _result = const JsonEncoder.withIndent('  ').convert(output);
      });
    } catch (e) {
      setState(() {
        _result = 'Unexpected error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appwrite Function Debugger'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected collections (comma-separated)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _selectedCollectionsController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'collectionA, collectionB',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _runDeleteAll,
                    child: const Text('Run Delete All'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _isLoading ? null : _runDeleteSelected,
                    child: const Text('Run Delete Selected'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text(
              'Execution Result',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F5F7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD4DEE6)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _result,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
