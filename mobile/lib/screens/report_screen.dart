import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animate_do/animate_do.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/report_provider.dart';
import '../providers/location_provider.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/complaint_letter_widget.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _step = 0;
  XFile? _photo;
  final _area = TextEditingController();
  final _desc = TextEditingController();
  bool _analyzing = false;
  String _analysisMsg = '';
  final _picker = ImagePicker();
  String _language = 'en';

  // Voice
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _recordingPath;
  String? _lastRecordedPath; // Keep after transcribe so user can play their voice

  // Play recorded voice (original user recording)
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingRecording = false;

  // TTS — optional: read description aloud
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _desc.addListener(() => setState(() {}));
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingRecording = false);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _tts.stop();
    _recorder.dispose();
    _area.dispose();
    _desc.dispose();
    super.dispose();
  }

  /// Play the user's original voice recording (not TTS).
  Future<void> _playRecordedVoice() async {
    if (_lastRecordedPath == null || _isPlayingRecording) return;
    final path = _lastRecordedPath!;
    if (!File(path).existsSync()) return;
    setState(() => _isPlayingRecording = true);
    try {
      await _audioPlayer.play(DeviceFileSource(path));
    } catch (_) {
      if (mounted) setState(() => _isPlayingRecording = false);
    }
  }

  Future<void> _speakDescription() async {
    final text = _desc.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSpeaking = true);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    try {
      await _tts.setLanguage(_language == 'kn' ? 'kn-IN' : _language == 'hi' ? 'hi-IN' : 'en-IN');
      await _tts.speak(text);
    } catch (_) {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<void> _pick(ImageSource src) async {
    final img = await _picker.pickImage(source: src, imageQuality: 85);
    if (img != null) setState(() => _photo = img);
  }

  Future<void> _getLocation() async {
    final loc = context.read<LocationProvider>();
    await loc.getCurrentLocation();
    if (loc.areaName.isNotEmpty &&
        !loc.areaName.contains('error') &&
        !loc.areaName.contains('denied')) {
      setState(() => _area.text = loc.areaName);
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _recordingPath = '${dir.path}/vn_voice_${DateTime.now().millisecondsSinceEpoch}.wav';
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: _recordingPath!,
        );
        setState(() => _isRecording = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Microphone permission required'),
            backgroundColor: VNColors.red,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Recording error: $e'),
          backgroundColor: VNColors.red,
        ));
      }
    }
  }

  Future<void> _stopAndTranscribe() async {
    try {
      await _recorder.stop();
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });

      if (_recordingPath != null && File(_recordingPath!).existsSync()) {
        final path = _recordingPath!;
        final result = await ApiService.transcribeVoice(path, _language);
        final text = result['transcription'] ?? '';
        if (text.isNotEmpty && mounted) {
          setState(() {
            _desc.text = _desc.text.isEmpty ? text : '${_desc.text} $text';
            _lastRecordedPath = path; // Keep so user can play their voice
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Nova 2 Sonic: "$text"'),
            backgroundColor: VNColors.green,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Transcription error: $e'),
          backgroundColor: VNColors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      await StorageService.savePendingReport({
        'photoPath': _photo!.path,
        'area': _area.text,
        'lat': context.read<LocationProvider>().lat ?? 12.9716,
        'lng': context.read<LocationProvider>().lng ?? 77.5946,
        'description': _desc.text,
      });
      _showLoginGate();
      return;
    }

    setState(() {
      _analyzing = true;
      _analysisMsg = 'Uploading to S3...';
    });
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _analysisMsg = 'Nova 2 Lite analyzing pollution...');
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _analysisMsg = 'Generating KSPCB complaint letter...');

    final loc = context.read<LocationProvider>();
    await context.read<ReportProvider>().submitReport(
      photoPath: _photo!.path,
      area: _area.text,
      lat: loc.lat ?? 12.9716,
      lng: loc.lng ?? 77.5946,
      description: _desc.text,
    );
    setState(() {
      _analyzing = false;
      _step = 2;
    });
  }

  void _showLoginGate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VNColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _LoginGate(onSuccess: () async {
          Navigator.pop(context);
          final p = await StorageService.getPendingReport();
          if (p != null) {
            _area.text = p['area'] ?? '';
            _desc.text = p['description'] ?? '';
            await StorageService.clearPendingReport();
            await _submit();
          }
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: VNColors.bg,
        appBar: AppBar(
          backgroundColor: VNColors.bg,
          title: const Text('Report Pollution',
              style: TextStyle(
                  fontFamily: 'Rajdhani', fontSize: 20, color: VNColors.text)),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: VNColors.text),
              onPressed: () => Navigator.pop(context)),
        ),
        body: _step == 0
            ? _buildStep1()
            : _step == 1
                ? _buildStep2()
                : _buildResult(),
      );

  // ── STEP 1: PHOTO ─────────────────────────────────────────
  Widget _buildStep1() => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _StepIndicator(step: 0),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _pick(ImageSource.camera),
            child: Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                color: VNColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _photo != null ? VNColors.cyan : VNColors.border,
                    width: _photo != null ? 2 : 1),
              ),
              child: _photo == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.camera_alt_outlined,
                            color: VNColors.cyan, size: 64),
                        SizedBox(height: 12),
                        Text('Tap to take photo',
                            style: TextStyle(
                                fontFamily: 'DMSans',
                                color: VNColors.muted,
                                fontSize: 15)),
                        Text('or use buttons below',
                            style: TextStyle(
                                fontFamily: 'DMSans',
                                color: VNColors.muted,
                                fontSize: 13)),
                      ],
                    )
                  : Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(File(_photo!.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _photo = null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text('Change',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'DMSans')),
                          ),
                        ),
                      ),
                    ]),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: VNButton(
                    label: 'Camera',
                    icon: Icons.camera_alt,
                    outlined: true,
                    onTap: () => _pick(ImageSource.camera))),
            const SizedBox(width: 10),
            Expanded(
                child: VNButton(
                    label: 'Gallery',
                    icon: Icons.photo_library,
                    outlined: true,
                    color: VNColors.cyan,
                    onTap: () => _pick(ImageSource.gallery))),
          ]),
          const SizedBox(height: 24),
          VNButton(
            label: 'Next: Add Details →',
            color: VNColors.saffron,
            onTap: _photo == null ? null : () => setState(() => _step = 1),
          ),
        ]),
      );

  // ── STEP 2: DETAILS + VOICE ───────────────────────────────
  Widget _buildStep2() {
    final loc = context.watch<LocationProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StepIndicator(step: 1),
        const SizedBox(height: 24),

        // Area field
        TextField(
          controller: _area,
          style: const TextStyle(color: VNColors.text, fontFamily: 'DMSans'),
          decoration: InputDecoration(
            hintText: 'Area (e.g. Koramangala, Whitefield)',
            hintStyle: const TextStyle(color: VNColors.muted),
            prefixIcon:
                const Icon(Icons.location_on_outlined, color: VNColors.muted),
            filled: true,
            fillColor: VNColors.bgCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: VNColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: VNColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: VNColors.cyan)),
          ),
        ),
        const SizedBox(height: 10),

        // GPS button
        OutlinedButton.icon(
          onPressed: _getLocation,
          icon: loc.loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: VNColors.cyan, strokeWidth: 2))
              : const Icon(Icons.my_location, color: VNColors.cyan, size: 18),
          label: Text(loc.loading ? 'Detecting...' : 'Use My GPS Location',
              style:
                  const TextStyle(color: VNColors.cyan, fontFamily: 'DMSans')),
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: VNColors.cyan)),
        ),
        if (loc.lat != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'GPS: ${loc.lat!.toStringAsFixed(4)}, ${loc.lng!.toStringAsFixed(4)}',
              style: const TextStyle(
                  fontSize: 11, color: VNColors.muted, fontFamily: 'DMSans'),
            ),
          ),
        const SizedBox(height: 16),

        // Description
        TextField(
          controller: _desc,
          maxLines: 4,
          style: const TextStyle(color: VNColors.text, fontFamily: 'DMSans'),
          decoration: InputDecoration(
            hintText: 'Describe the pollution — or use voice below',
            hintStyle: const TextStyle(color: VNColors.muted),
            filled: true,
            fillColor: VNColors.bgCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: VNColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: VNColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: VNColors.cyan)),
          ),
        ),
        if (_lastRecordedPath != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _isPlayingRecording ? null : _playRecordedVoice,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: VNColors.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: VNColors.cyan.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isPlayingRecording ? Icons.volume_up : Icons.play_circle_outline,
                    color: VNColors.cyan,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isPlayingRecording ? 'Playing your recording...' : 'Listen to your recording',
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 13,
                      color: VNColors.cyan,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_desc.text.trim().isNotEmpty && _lastRecordedPath == null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _isSpeaking ? null : _speakDescription,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: VNColors.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: VNColors.cyan.withOpacity(0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up_outlined, color: VNColors.cyan, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Read description aloud',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 13,
                      color: VNColors.cyan,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),

        // ── NOVA 2 SONIC VOICE SECTION ────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VNColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: VNColors.saffron.withOpacity(0.4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.mic, color: VNColors.saffron, size: 18),
              SizedBox(width: 6),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Nova 2 Sonic — Voice Report',
                    style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: VNColors.saffron)),
                Text('Speak in English, Kannada, or Hindi',
                    style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 11,
                        color: VNColors.muted)),
              ]),
            ]),
            const SizedBox(height: 12),

            // Language selector
            Row(
              children: ['en', 'kn', 'hi'].map((lang) {
                final labels = {
                  'en': '🇬🇧 English',
                  'kn': '🇮🇳 ಕನ್ನಡ',
                  'hi': '🇮🇳 हिंदी'
                };
                final active = _language == lang;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _language = lang),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? VNColors.saffron.withOpacity(0.2)
                            : Colors.transparent,
                        border: Border.all(
                            color: active
                                ? VNColors.saffron
                                : VNColors.border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(labels[lang]!,
                          style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 12,
                              color: active
                                  ? VNColors.saffron
                                  : VNColors.muted)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Record / transcribing button
            if (_isTranscribing)
              const Center(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: VNColors.saffron, strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Nova 2 Sonic transcribing...',
                          style: TextStyle(
                              fontFamily: 'DMSans',
                              color: VNColors.muted,
                              fontSize: 13)),
                    ]),
              )
            else
              GestureDetector(
                onTap:
                    _isRecording ? _stopAndTranscribe : _startRecording,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? VNColors.red.withOpacity(0.15)
                        : VNColors.saffron.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _isRecording
                            ? VNColors.red
                            : VNColors.saffron),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            _isRecording
                                ? Icons.stop_circle
                                : Icons.mic,
                            color: _isRecording
                                ? VNColors.red
                                : VNColors.saffron,
                            size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isRecording
                                ? '🔴  Recording...  Tap to stop & transcribe'
                                : '🎙️  Tap to Record Voice',
                            style: TextStyle(
                              fontFamily: 'Rajdhani',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _isRecording
                                  ? VNColors.red
                                  : VNColors.saffron,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),

        // Nova info banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VNColors.cyan.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: VNColors.border),
          ),
          child: const Row(children: [
            Icon(Icons.auto_awesome, color: VNColors.cyan, size: 18),
            SizedBox(width: 8),
            Expanded(
                child: Text(
              'Nova 2 Lite will analyze your photo and generate a KSPCB + BBMP complaint letter automatically',
              style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 12,
                  color: VNColors.muted),
            )),
          ]),
        ),
        const SizedBox(height: 24),

        Row(children: [
          Expanded(
              child: VNButton(
                  label: '← Back',
                  outlined: true,
                  color: VNColors.muted,
                  onTap: () => setState(() => _step = 0))),
          const SizedBox(width: 10),
          Expanded(
              child: Consumer<ReportProvider>(
                  builder: (_, reps, __) => VNButton(
                        label: 'Analyze with Nova →',
                        loading: _analyzing,
                        color: VNColors.saffron,
                        onTap: _area.text.isEmpty ? null : _submit,
                      ))),
        ]),

        if (_analyzing) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: VNColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: VNColors.cyan.withOpacity(0.3)),
            ),
            child: Column(children: [
              Pulse(
                  infinite: true,
                  child: const Icon(Icons.visibility,
                      color: VNColors.cyan, size: 48)),
              const SizedBox(height: 12),
              const Text('Nova 2 Lite Analyzing...',
                  style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 18,
                      color: VNColors.cyan,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_analysisMsg,
                  style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 13,
                      color: VNColors.muted)),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── STEP 3: RESULT ────────────────────────────────────────
  Widget _buildResult() {
    final reps = context.watch<ReportProvider>();
    final report = reps.lastSubmitted;
    final analysis = report?.analysis;
    if (analysis == null) {
      final err = reps.error ?? 'No result';
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _StepIndicator(step: 2),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: VNColors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: VNColors.red),
            ),
            child: Column(children: [
              const Icon(Icons.error_outline, color: VNColors.red, size: 48),
              const SizedBox(height: 12),
              const Text('Submission failed',
                  style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: VNColors.red)),
              const SizedBox(height: 8),
              Text(err,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 14,
                      color: VNColors.text)),
            ]),
          ),
          const SizedBox(height: 24),
          VNButton(
            label: '← Try again',
            outlined: true,
            icon: Icons.refresh,
            onTap: () => setState(() => _step = 1),
          ),
          const SizedBox(height: 10),
          VNButton(
            label: 'Back to photo',
            color: VNColors.cyan,
            onTap: () {
              context.read<ReportProvider>().clearError();
              setState(() {
                _step = 0;
                _photo = null;
                _area.clear();
                _desc.clear();
              });
            },
          ),
        ]),
      );
    }

    Color sevColor(String s) {
      switch (s.toUpperCase()) {
        case 'CRITICAL': return VNColors.red;
        case 'HIGH':     return VNColors.orange;
        case 'MODERATE': return VNColors.yellow;
        default:         return VNColors.green;
      }
    }

    String sevEmoji(String s) {
      switch (s.toUpperCase()) {
        case 'CRITICAL': return '🔴';
        case 'HIGH':     return '🟠';
        case 'MODERATE': return '🟡';
        default:         return '🟢';
      }
    }

    // Pollution (and complaint) shown only for MODERATE / HIGH / CRITICAL
    final showPollutionAndComplaint = ['MODERATE', 'HIGH', 'CRITICAL']
        .contains(analysis.severity.toUpperCase());

    if (!showPollutionAndComplaint) {
      // LOW: report saved, no complaint letter
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: FadeInUp(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _StepIndicator(step: 2),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: VNColors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VNColors.green),
              ),
              child: Column(children: [
                Text(
                  '${sevEmoji(analysis.severity)} ${analysis.severity.toUpperCase()} POLLUTION',
                  style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: VNColors.green,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Report saved. No complaint letter is generated for low severity.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 14,
                    color: VNColors.text,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: VNButton(
                  label: 'My Reports',
                  outlined: true,
                  icon: Icons.list,
                  onTap: () => Navigator.pushNamed(
                      context, AppConstants.myReports),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: VNButton(
                  label: 'Report Again',
                  icon: Icons.add_a_photo,
                  color: VNColors.saffron,
                  onTap: () => setState(() {
                    _step = 0;
                    _photo = null;
                    _area.clear();
                    _desc.clear();
                  }),
                ),
              ),
            ]),
            const SizedBox(height: 40),
          ]),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: FadeInUp(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _StepIndicator(step: 2),
          const SizedBox(height: 20),

          // Severity banner (MODERATE / HIGH / CRITICAL)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: sevColor(analysis.severity).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: sevColor(analysis.severity)),
            ),
            child: Column(children: [
              Text(
                '${sevEmoji(analysis.severity)} ${analysis.severity.toUpperCase()} POLLUTION',
                style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: sevColor(analysis.severity)),
              ),
              Text(analysis.pollutionType,
                  style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 15,
                      color: VNColors.text)),
            ]),
          ),
          const SizedBox(height: 14),

          // Nova badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: VNColors.cyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: VNColors.border),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome, color: VNColors.cyan, size: 14),
              SizedBox(width: 4),
              Text('Analyzed by Amazon Nova 2 Lite',
                  style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      color: VNColors.cyan)),
            ]),
          ),
          const SizedBox(height: 14),

          // Report section — AQI levels
          Text('POLLUTION REPORT',
              style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: VNColors.muted)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: VNColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: VNColors.border),
            ),
            child: Row(children: [
              Icon(Icons.air, color: sevColor(analysis.severity), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimated AQI impact',
                          style: const TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 12,
                              color: VNColors.muted)),
                      Text(analysis.estimatedAqiImpact,
                          style: TextStyle(
                              fontFamily: 'Rajdhani',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: sevColor(analysis.severity))),
                      const SizedBox(height: 2),
                      Text('AQI range: ${analysis.estimatedAqiRange}',
                          style: const TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 12,
                              color: VNColors.text)),
                    ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Health risk
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VNColors.yellow.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: VNColors.yellow.withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.health_and_safety_outlined,
                  color: VNColors.yellow, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(analysis.healthRisk,
                      style: const TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 13,
                          color: VNColors.text))),
            ]),
          ),
          const SizedBox(height: 12),

          Text(analysis.description,
              style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 14,
                  color: VNColors.text,
                  height: 1.6)),
          const SizedBox(height: 12),

          // Confidence bar
          Row(children: [
            const Text('Nova AI Confidence: ',
                style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 13,
                    color: VNColors.muted)),
            Text('${(analysis.confidence * 100).toInt()}%',
                style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: VNColors.cyan)),
          ]),
          const SizedBox(height: 6),
          LinearPercentIndicator(
            percent: analysis.confidence.clamp(0.0, 1.0),
            lineHeight: 6,
            progressColor: VNColors.cyan,
            backgroundColor: VNColors.bgCard2,
            barRadius: const Radius.circular(3),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),

          // Recommendations
          if (analysis.recommendations.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: VNColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                    left: BorderSide(color: VNColors.cyan, width: 3)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.lightbulb_outline,
                          color: VNColors.cyan, size: 18),
                      SizedBox(width: 6),
                      Text('Recommendations',
                          style: TextStyle(
                              fontFamily: 'Rajdhani',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: VNColors.cyan)),
                    ]),
                    const SizedBox(height: 8),
                    ...analysis.recommendations.map((r) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('• $r',
                              style: const TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 13,
                                  color: VNColors.text)),
                        )),
                  ]),
            ),
          const SizedBox(height: 16),

          // Complaint letter (only for MODERATE/HIGH/CRITICAL)
          if (analysis.complaintLetter.isNotEmpty) ...[
            Text('COMPLAINT LETTER',
                style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: VNColors.muted)),
            const SizedBox(height: 8),
            ComplaintLetterWidget(letter: analysis.complaintLetter),
            const SizedBox(height: 16),
          ],

          // Buttons
          Row(children: [
            Expanded(
                child: VNButton(
                    label: 'My Reports',
                    outlined: true,
                    icon: Icons.list,
                    onTap: () => Navigator.pushNamed(
                        context, AppConstants.myReports))),
            const SizedBox(width: 10),
            Expanded(
                child: VNButton(
                    label: 'Report Again',
                    icon: Icons.add_a_photo,
                    color: VNColors.saffron,
                    onTap: () => setState(() {
                          _step = 0;
                          _photo = null;
                          _area.clear();
                          _desc.clear();
                        }))),
          ]),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

// ── STEP INDICATOR ─────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
            3,
            (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= step
                          ? VNColors.cyan.withOpacity(0.2)
                          : VNColors.bgCard,
                      border: Border.all(
                          color:
                              i <= step ? VNColors.cyan : VNColors.border,
                          width: i == step ? 2 : 1),
                    ),
                    child: Center(
                        child: Text('${i + 1}',
                            style: TextStyle(
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.bold,
                                color: i <= step
                                    ? VNColors.cyan
                                    : VNColors.muted))),
                  ),
                )),
      );
}

// ── LOGIN GATE ─────────────────────────────────────────────────
class _LoginGate extends StatefulWidget {
  final VoidCallback onSuccess;
  const _LoginGate({required this.onSuccess});
  @override
  State<_LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<_LoginGate> {
  final _e = TextEditingController();
  final _p = TextEditingController();
  void _login() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_e.text.trim(), _p.text);
    if (ok && mounted) widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Login to Submit',
                  style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: VNColors.text)),
              const Text('Your photo is saved. Login to submit.',
                  style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 13,
                      color: VNColors.muted)),
              const SizedBox(height: 16),
              TextField(
                  controller: _e,
                  style: const TextStyle(color: VNColors.text),
                  decoration: InputDecoration(
                    hintText: 'Email',
                    hintStyle:
                        const TextStyle(color: VNColors.muted),
                    filled: true,
                    fillColor: VNColors.bgCard,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: VNColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: VNColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: VNColors.cyan)),
                  )),
              const SizedBox(height: 10),
              TextField(
                  controller: _p,
                  obscureText: true,
                  style: const TextStyle(color: VNColors.text),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle:
                        const TextStyle(color: VNColors.muted),
                    filled: true,
                    fillColor: VNColors.bgCard,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: VNColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: VNColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: VNColors.cyan)),
                  )),
              const SizedBox(height: 16),
              Consumer<AuthProvider>(
                  builder: (_, auth, __) => VNButton(
                      label: 'Login & Submit',
                      loading: auth.loading,
                      onTap: _login)),
              const SizedBox(height: 16),
            ]),
      );
}
