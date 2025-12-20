import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef OptionsBuilder<T> = FutureOr<List<T>> Function(String query);

class KeyboardAutocompleteField<T> extends StatefulWidget {
  const KeyboardAutocompleteField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.optionsBuilder,
    required this.displayStringForOption,
    required this.onSelected,
    this.decoration,
    this.hintText,
    this.minChars = 1,
    this.debounce = const Duration(milliseconds: 120),
    this.maxOptions = 20,
    this.optionBuilder,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;

  final OptionsBuilder<T> optionsBuilder;
  final String Function(T) displayStringForOption;
  final ValueChanged<T> onSelected;

  final InputDecoration? decoration;
  final String? hintText;

  final int minChars;
  final Duration debounce;
  final int maxOptions;

  /// Si null => rendu par défaut (ListTile).
  final Widget Function(BuildContext context, T option, bool highlighted)?
      optionBuilder;

  final bool enabled;

  @override
  State<KeyboardAutocompleteField<T>> createState() =>
      _KeyboardAutocompleteFieldState<T>();
}

class _KeyboardAutocompleteFieldState<T>
    extends State<KeyboardAutocompleteField<T>> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();

  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  final ScrollController _scrollController = ScrollController();

  OverlayEntry? _overlayEntry;

  List<T> _options = const [];
  int _highlightIndex = -1;

  Timer? _debounceTimer;
  int _requestId = 0;

  bool get _hasOverlay => _overlayEntry != null;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant KeyboardAutocompleteField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }

    // Si focusNode fourni change, on ne détruit pas celui du parent.
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      widget.focusNode?.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _debounceTimer?.cancel();
    _removeOverlay();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    } else {
      // Si déjà des options, on peut réafficher.
      if (_options.isNotEmpty) _ensureOverlay();
    }
  }

  void _onTextChanged() {
    if (!_focusNode.hasFocus) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () async {
      final q = widget.controller.text.trim();
      if (q.length < widget.minChars) {
        setState(() {
          _options = const [];
          _highlightIndex = -1;
        });
        _removeOverlay();
        return;
      }

      final int myReq = ++_requestId;
      final res = await widget.optionsBuilder(q);
      if (!mounted) return;
      if (myReq != _requestId) return; // évite les retours async dans le désordre

      final limited = res.length > widget.maxOptions
          ? res.sublist(0, widget.maxOptions)
          : res;

      setState(() {
        _options = limited;
        _highlightIndex = limited.isEmpty ? -1 : 0;
      });

      if (_options.isEmpty) {
        _removeOverlay();
      } else {
        _ensureOverlay();
      }
    });
  }

  void _ensureOverlay() {
    if (!_hasOverlay) {
      _overlayEntry = _buildOverlayEntry();
      Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectOption(T option) {
    final text = widget.displayStringForOption(option);
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onSelected(option);
    _removeOverlay();
  }

  int _clampHighlight(int index) {
    if (_options.isEmpty) return -1;
    if (index < 0) return 0;
    if (index >= _options.length) return _options.length - 1;
    return index;
  }

  void _moveHighlight(int delta) {
    if (_options.isEmpty) return;
    setState(() {
      _highlightIndex = _clampHighlight(_highlightIndex + delta);
    });
    _ensureOverlay();
    _scrollToHighlight();
  }

  void _scrollToHighlight() {
    if (_highlightIndex < 0) return;
    // approx : 48px par item (ListTile)
    final target = _highlightIndex * 48.0;
    _scrollController.animateTo(
      target.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_options.isNotEmpty) {
        _ensureOverlay();
        _moveHighlight(1);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_options.isNotEmpty) {
        _ensureOverlay();
        _moveHighlight(-1);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.enter) {
      if (_hasOverlay &&
          _highlightIndex >= 0 &&
          _highlightIndex < _options.length) {
        _selectOption(_options[_highlightIndex]);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.escape) {
      if (_hasOverlay) {
        _removeOverlay();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final renderBox =
            _fieldKey.currentContext?.findRenderObject() as RenderBox?;
        final size = renderBox?.size ?? const Size(300, 48);

        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 6),
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: _options.length,
                  itemBuilder: (context, index) {
                    final opt = _options[index];
                    final highlighted = index == _highlightIndex;

                    final child = widget.optionBuilder?.call(
                          context,
                          opt,
                          highlighted,
                        ) ??
                        Container(
                          color: highlighted
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.12)
                              : null,
                          child: ListTile(
                            dense: true,
                            title: Text(widget.displayStringForOption(opt)),
                          ),
                        );

                    return InkWell(
                      onTap: () => _selectOption(opt),
                      child: child,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dec = (widget.decoration ?? const InputDecoration()).copyWith(
      hintText: widget.hintText ?? widget.decoration?.hintText,
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _onKeyEvent,
        child: TextField(
          key: _fieldKey,
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          decoration: dec,
        ),
      ),
    );
  }
}
