import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Health Check Widget pour vérifier l'état du backend WebSocket
class StreamingHealthCheck extends StatefulWidget {
  final String backendUrl;
  final VoidCallback? onRefresh;

  const StreamingHealthCheck({
    super.key,
    required this.backendUrl,
    this.onRefresh,
  });

  @override
  State<StreamingHealthCheck> createState() => _StreamingHealthCheckState();
}

class _StreamingHealthCheckState extends State<StreamingHealthCheck> {
  static const Color prestoOrange = Color(0xFFFF6600);

  bool? _isHealthy;
  String? _errorMessage;
  DateTime? _lastCheck;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    if (!mounted) return;
    setState(() => _isHealthy = null);

    try {
      // Extract base URL from WebSocket URL
      // From: wss://presto-microia-stream-151421230024.us-east1.run.app/stream
      // To: https://presto-microia-stream-151421230024.us-east1.run.app/health
      final baseUrl = widget.backendUrl
          .replaceFirst('wss://', 'https://')
          .replaceFirst('/stream', '/health');

      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _isHealthy = true;
          _errorMessage = null;
          _lastCheck = DateTime.now();
        });
      } else {
        setState(() {
          _isHealthy = false;
          _errorMessage = 'HTTP ${response.statusCode}';
          _lastCheck = DateTime.now();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isHealthy = false;
        _errorMessage = e.toString().split('\n').first;
        _lastCheck = DateTime.now();
      });
    }
  }

  String get _statusText {
    if (_isHealthy == null) return 'Vérification...';
    if (_isHealthy == true) return 'En ligne';
    return 'Hors ligne';
  }

  Color get _statusColor {
    if (_isHealthy == null) return Colors.grey;
    if (_isHealthy == true) return Colors.green;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final lastCheckText = _lastCheck != null
        ? '${_lastCheck!.hour.toString().padLeft(2, '0')}:${_lastCheck!.minute.toString().padLeft(2, '0')}'
        : '—';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE8E8E8), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'État du Backend',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        widget.backendUrl,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _statusColor,
                              boxShadow: _isHealthy == true
                                  ? [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _statusColor,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check: $lastCheckText',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 14, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _checkHealth,
              style: ElevatedButton.styleFrom(
                backgroundColor: prestoOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Vérifier'),
            ),
          ],
        ),
      ),
    );
  }
}
