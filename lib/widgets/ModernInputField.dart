import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Constants/colorconstant.dart';

class ModernInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;
  final int maxLines;
  final VoidCallback? onTap;
  final bool readOnly;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool showLabel;
  final bool showClearButton;

  const ModernInputField({
    Key? key,
    required this.controller,
    required this.label,
    required this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.onTap,
    this.readOnly = false,
    this.maxLength,
    this.inputFormatters,
    this.showLabel = true,
    this.showClearButton = true,
  }) : super(key: key);

  @override
  State<ModernInputField> createState() => _ModernInputFieldState();
}

class _ModernInputFieldState extends State<ModernInputField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
    _hasText = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _onTextChange() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLabelFloating = _isFocused || _hasText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Input Field
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _isFocused ? AppColors.primary : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  validator: widget.validator,
                  enabled: widget.enabled,
                  maxLines: widget.maxLines,
                  onTap: widget.onTap,
                  readOnly: widget.readOnly,
                  maxLength: widget.maxLength,
                  inputFormatters: widget.inputFormatters,
                  style: TextStyle(
                    fontSize: 16,
                    color: widget.enabled ? Colors.black87 : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '',
                    prefixIcon: widget.prefixIcon != null
                        ? Padding(
                            padding: const EdgeInsets.only(left: 16, right: 12),
                            child: Icon(
                              widget.prefixIcon,
                              color: _isFocused
                                  ? AppColors.primary
                                  : Colors.grey[400],
                              size: 22,
                            ),
                          )
                        : null,
                    suffixIcon: widget.showClearButton && _hasText
                        ? IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            onPressed: () {
                              widget.controller.clear();
                            },
                          )
                        : widget.suffixIcon,
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: widget.prefixIcon != null ? 4 : 20,
                      vertical: 17,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Floating Label
              Positioned(
                left: widget.prefixIcon != null ? 60 : 20,
                right: 60,
                top: isLabelFloating ? -10 : 22,
                child: IgnorePointer(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontSize: isLabelFloating ? 13 : 16,
                      color: isLabelFloating
                          ? (_isFocused ? AppColors.primary : Colors.grey[600])
                          : Colors.grey[600],
                      fontWeight:
                          isLabelFloating ? FontWeight.w600 : FontWeight.normal,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.symmetric(
                        horizontal: isLabelFloating ? 6 : 0,
                        vertical: isLabelFloating ? 2 : 0,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isLabelFloating ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.label,
                        maxLines: isLabelFloating ? 2 : 1,
                        overflow: isLabelFloating ? TextOverflow.visible : TextOverflow.ellipsis,
                        softWrap: isLabelFloating,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Character counter outside the box
        if (widget.maxLength != null)
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${widget.controller.text.length}/${widget.maxLength}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const ModernButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: textColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
