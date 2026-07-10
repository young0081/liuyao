import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ai_provider.dart';
import '../../state/ai_state.dart';
import '../theme.dart';

/// 供应商预设，便于一键填入常见 baseUrl。
class _Preset {
  const _Preset(this.name, this.baseUrl, this.model);
  final String name;
  final String baseUrl;
  final String model;
}

const List<_Preset> _presets = [
  _Preset('OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'),
  _Preset('DeepSeek', 'https://api.deepseek.com/v1', 'deepseek-chat'),
  _Preset('Moonshot', 'https://api.moonshot.cn/v1', 'moonshot-v1-8k'),
  _Preset('智谱 GLM', 'https://open.bigmodel.cn/api/paas/v4', 'glm-4-flash'),
  _Preset(
    '通义千问',
    'https://dashscope.aliyuncs.com/compatible-mode/v1',
    'qwen-plus',
  ),
  _Preset('本地 Ollama', 'http://localhost:11434/v1', 'qwen2.5'),
];

Future<void> showAiSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const _AiSettingsDialog(),
  );
}

class _AiSettingsDialog extends ConsumerStatefulWidget {
  const _AiSettingsDialog();

  @override
  ConsumerState<_AiSettingsDialog> createState() => _AiSettingsDialogState();
}

class _AiSettingsDialogState extends ConsumerState<_AiSettingsDialog> {
  // 当前正在编辑的供应商 id；为 null 表示未选中/新建态。
  String? _editingId;
  bool _creatingNew = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiProvider).settings;
    _editingId =
        settings.active?.id ??
        (settings.providers.isNotEmpty ? settings.providers.first.id : null);
    if (settings.providers.isEmpty) _creatingNew = true;
  }

  AiProviderConfig? get _editing {
    if (_creatingNew) return null;
    final list = ref.read(aiProvider).settings.providers;
    for (final p in list) {
      if (p.id == _editingId) return p;
    }
    return null;
  }

  void _newProvider() {
    setState(() {
      _creatingNew = true;
      _editingId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiProvider).settings;
    final media = MediaQuery.of(context);
    // 窄屏（移动端）改为近全屏、上下堆叠布局。
    final narrow = media.size.width < 620;
    final maxW = narrow ? media.size.width - 24 : 780.0;
    final maxH = narrow
        ? media.size.height -
              media.padding.vertical -
              media.viewInsets.vertical -
              32
        : 620.0;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 12 : 40,
        vertical: narrow ? 24 : 40,
      ),
      backgroundColor: XuanTheme.inkPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: XuanTheme.lineSoft),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            Flexible(
              child: narrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _providerList(settings, horizontal: true),
                        const Divider(height: 1, color: XuanTheme.line),
                        Expanded(child: _form()),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 240, child: _providerList(settings)),
                        const VerticalDivider(width: 1, color: XuanTheme.line),
                        Expanded(child: _form()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    return _creatingNew || _editing == null
        ? _ProviderForm(
            key: const ValueKey('new'),
            initial: null,
            onSaved: (cfg) {
              setState(() {
                _creatingNew = false;
                _editingId = cfg.id;
              });
            },
          )
        : _ProviderForm(
            key: ValueKey(_editing!.id),
            initial: _editing,
            onSaved: (cfg) => setState(() => _editingId = cfg.id),
          );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: XuanTheme.line)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_outlined, size: 18, color: XuanTheme.gold),
          const SizedBox(width: 10),
          const Text(
            'AI 供应商管理',
            style: TextStyle(
              color: XuanTheme.textMain,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            splashRadius: 18,
            icon: const Icon(Icons.close, size: 18, color: XuanTheme.textDim),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _providerList(AiSettings settings, {bool horizontal = false}) {
    // 窄屏：供应商横向排布，限制高度，避免占满整屏。
    if (horizontal) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: settings.providers.isEmpty ? 40 : 72,
              child: settings.providers.isEmpty
                  ? const Center(
                      child: Text(
                        '尚无供应商，点击下方新增',
                        style: TextStyle(
                          color: XuanTheme.textDim,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: settings.providers.length,
                      separatorBuilder: (_, i) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final p = settings.providers[i];
                        final selected = !_creatingNew && p.id == _editingId;
                        final isActive = p.id == settings.activeId;
                        return SizedBox(
                          width: 172,
                          child: _ProviderTile(
                            name: p.name,
                            model: p.model,
                            configured: p.isConfigured,
                            selected: selected,
                            isActive: isActive,
                            onTap: () => setState(() {
                              _creatingNew = false;
                              _editingId = p.id;
                            }),
                            onUse: () =>
                                ref.read(aiProvider.notifier).setActive(p.id),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 6),
            _GhostButton(label: '新增供应商', icon: Icons.add, onTap: _newProvider),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: settings.providers.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      '尚无供应商\n点击下方新增',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: XuanTheme.textDim,
                        fontSize: 12,
                        height: 1.7,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: settings.providers.length,
                  itemBuilder: (_, i) {
                    final p = settings.providers[i];
                    final selected = !_creatingNew && p.id == _editingId;
                    final isActive = p.id == settings.activeId;
                    return _ProviderTile(
                      name: p.name,
                      model: p.model,
                      configured: p.isConfigured,
                      selected: selected,
                      isActive: isActive,
                      onTap: () => setState(() {
                        _creatingNew = false;
                        _editingId = p.id;
                      }),
                      onUse: () =>
                          ref.read(aiProvider.notifier).setActive(p.id),
                    );
                  },
                ),
        ),
        const Divider(height: 1, color: XuanTheme.line),
        Padding(
          padding: const EdgeInsets.all(10),
          child: _GhostButton(
            label: '新增供应商',
            icon: Icons.add,
            onTap: _newProvider,
          ),
        ),
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.name,
    required this.model,
    required this.configured,
    required this.selected,
    required this.isActive,
    required this.onTap,
    required this.onUse,
  });
  final String name;
  final String model;
  final bool configured;
  final bool selected;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: XuanMotion.standard,
            curve: XuanMotion.ease,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? XuanTheme.gold.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border(
                left: BorderSide(
                  color: selected ? XuanTheme.gold : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected
                                    ? XuanTheme.goldSoft
                                    : XuanTheme.textMain,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!configured) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.error_outline,
                              size: 12,
                              color: XuanTheme.cinnabar,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: XuanTheme.textDim,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                _UseBadge(isActive: isActive, onTap: onUse),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UseBadge extends StatelessWidget {
  const _UseBadge({required this.isActive, required this.onTap});
  final bool isActive;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isActive ? '当前供应商' : '设为当前供应商',
      child: IconButton(
        onPressed: isActive ? null : onTap,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        icon: Icon(
          isActive ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 17,
          color: isActive ? XuanTheme.jade : XuanTheme.textDim,
        ),
      ),
    );
  }
}

/// 右侧编辑表单。
class _ProviderForm extends ConsumerStatefulWidget {
  const _ProviderForm({
    super.key,
    required this.initial,
    required this.onSaved,
  });
  final AiProviderConfig? initial;
  final ValueChanged<AiProviderConfig> onSaved;

  @override
  ConsumerState<_ProviderForm> createState() => _ProviderFormState();
}

class _ProviderFormState extends ConsumerState<_ProviderForm> {
  late TextEditingController _name;
  late TextEditingController _baseUrl;
  late TextEditingController _apiKey;
  late TextEditingController _model;
  late TextEditingController _prompt;
  late double _temperature;
  late bool _stream;
  bool _obscureKey = true;

  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    final cfg = widget.initial;
    _name = TextEditingController(text: cfg?.name ?? '');
    _baseUrl = TextEditingController(text: cfg?.baseUrl ?? '');
    _apiKey = TextEditingController(text: cfg?.apiKey ?? '');
    _model = TextEditingController(text: cfg?.model ?? '');
    _prompt = TextEditingController(
      text: cfg?.systemPrompt ?? AiProviderConfig.defaultSystemPrompt,
    );
    _temperature = cfg?.temperature ?? 0.7;
    _stream = cfg?.stream ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    _prompt.dispose();
    super.dispose();
  }

  AiProviderConfig _current() {
    final id =
        widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    return AiProviderConfig(
      id: id,
      name: _name.text.trim().isEmpty ? '未命名供应商' : _name.text.trim(),
      baseUrl: _baseUrl.text.trim(),
      apiKey: _apiKey.text.trim(),
      model: _model.text.trim(),
      temperature: _temperature,
      stream: _stream,
      systemPrompt: _prompt.text.trim().isEmpty
          ? AiProviderConfig.defaultSystemPrompt
          : _prompt.text.trim(),
    );
  }

  void _applyPreset(_Preset p) {
    setState(() {
      if (_name.text.trim().isEmpty) _name.text = p.name;
      _baseUrl.text = p.baseUrl;
      _model.text = p.model;
      _testResult = null;
    });
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final err = await ref.read(aiProvider.notifier).testConnection(_current());
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = err == null;
      _testResult = err ?? '连接正常，供应商可用。';
    });
  }

  Future<void> _save() async {
    final cfg = _current();
    await ref.read(aiProvider.notifier).upsertProvider(cfg);
    if (!mounted) return;
    widget.onSaved(cfg);
  }

  Future<void> _delete() async {
    final id = widget.initial?.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: XuanTheme.inkPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: XuanTheme.line),
        ),
        title: const Text(
          '删除供应商',
          style: TextStyle(color: XuanTheme.textMain, fontSize: 16),
        ),
        content: Text(
          '确定删除“${widget.initial!.name}”及其本机配置？',
          style: const TextStyle(color: XuanTheme.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '删除',
              style: TextStyle(color: XuanTheme.cinnabar),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(aiProvider.notifier).deleteProvider(id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldLabel('名称'),
                const SizedBox(height: 6),
                _field(controller: _name, hint: '如：我的 DeepSeek'),
                const SizedBox(height: 14),
                const _FieldLabel('供应商预设（一键填入地址与模型）'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in _presets)
                      _PresetChip(label: p.name, onTap: () => _applyPreset(p)),
                  ],
                ),
                const SizedBox(height: 16),
                const _FieldLabel('接口地址 (Base URL)'),
                const SizedBox(height: 6),
                _field(controller: _baseUrl, hint: 'https://api.openai.com/v1'),
                const SizedBox(height: 14),
                const _FieldLabel('API 密钥'),
                const SizedBox(height: 6),
                _field(
                  controller: _apiKey,
                  hint: 'sk-...',
                  obscure: _obscureKey,
                  suffix: IconButton(
                    splashRadius: 18,
                    icon: Icon(
                      _obscureKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: XuanTheme.textDim,
                    ),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '密钥仅保存在本机，不会上传或明文回显。',
                  style: TextStyle(color: XuanTheme.textDim, fontSize: 11),
                ),
                const SizedBox(height: 14),
                const _FieldLabel('模型名称'),
                const SizedBox(height: 6),
                _field(controller: _model, hint: 'gpt-4o-mini'),
                const SizedBox(height: 14),
                _FieldLabel('温度 (${_temperature.toStringAsFixed(1)})'),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: XuanTheme.gold,
                    inactiveTrackColor: XuanTheme.line,
                    thumbColor: XuanTheme.goldSoft,
                    overlayColor: XuanTheme.gold.withValues(alpha: 0.15),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _temperature,
                    min: 0,
                    max: 1.5,
                    divisions: 15,
                    onChanged: (v) => setState(() => _temperature = v),
                  ),
                ),
                const SizedBox(height: 6),
                _StreamToggle(
                  stream: _stream,
                  onChanged: (v) => setState(() => _stream = v),
                ),
                const SizedBox(height: 14),
                const _FieldLabel('系统提示词'),
                const SizedBox(height: 6),
                _field(controller: _prompt, hint: '设定解卦者的口吻与准则…', maxLines: 4),
                if (_testResult != null) ...[
                  const SizedBox(height: 14),
                  _testBanner(),
                ],
              ],
            ),
          ),
        ),
        _footer(context),
      ],
    );
  }

  Widget _testBanner() {
    final color = _testOk ? XuanTheme.jade : XuanTheme.cinnabar;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _testOk ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _testResult!,
              style: TextStyle(color: color, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final canDelete = widget.initial != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: XuanTheme.lineSoft)),
      ),
      child: Row(
        children: [
          _GhostButton(
            label: _testing ? '测试中…' : '测试连接',
            icon: Icons.wifi_tethering,
            onTap: _testing ? null : _test,
          ),
          if (canDelete) ...[
            const SizedBox(width: 10),
            _GhostButton(
              label: '删除',
              icon: Icons.delete_outline,
              danger: true,
              onTap: _delete,
            ),
          ],
          const Spacer(),
          _SolidButton(label: '保存', onTap: _save),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    int maxLines = 1,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      inputFormatters: maxLines == 1
          ? [FilteringTextInputFormatter.singleLineFormatter]
          : null,
      style: const TextStyle(color: XuanTheme.textMain, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: suffix,
        isDense: true,
      ),
    );
  }
}

class _StreamToggle extends StatelessWidget {
  const _StreamToggle({required this.stream, required this.onChanged});
  final bool stream;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: XuanTheme.inkRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: XuanTheme.lineSoft),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final segW = (c.maxWidth - 6) / 2;
          return Stack(
            children: [
              AnimatedAlign(
                duration: XuanMotion.standard,
                curve: XuanMotion.emphasized,
                alignment: stream
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: segW,
                  height: 30,
                  decoration: BoxDecoration(
                    color: XuanTheme.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: XuanTheme.gold.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              Row(children: [_seg('流式（逐字）', true), _seg('非流式（一次性）', false)]),
            ],
          );
        },
      ),
    );
  }

  Widget _seg(String label, bool v) {
    final active = stream == v;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(v),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 30,
            alignment: Alignment.center,
            child: AnimatedDefaultTextStyle(
              duration: XuanMotion.standard,
              curve: XuanMotion.ease,
              style: TextStyle(
                color: active ? XuanTheme.goldSoft : XuanTheme.textDim,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: XuanTheme.gold,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: XuanTheme.inkRaised,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: XuanTheme.line),
          ),
          child: Text(
            label,
            style: const TextStyle(color: XuanTheme.textMain, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    this.icon,
    required this.onTap,
    this.danger = false,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = danger
        ? XuanTheme.cinnabar
        : (enabled ? XuanTheme.textMain : XuanTheme.textDim);
    return TextButton.icon(
      onPressed: onTap,
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: 15, color: fg),
      label: Text(label, style: TextStyle(color: fg, fontSize: 13)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: BorderSide(
            color: danger
                ? XuanTheme.cinnabar.withValues(alpha: 0.5)
                : XuanTheme.line,
          ),
        ),
      ),
    );
  }
}

class _SolidButton extends StatelessWidget {
  const _SolidButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: XuanTheme.gold,
        foregroundColor: XuanTheme.ink,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}
