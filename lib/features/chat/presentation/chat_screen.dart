import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../l10n/app_localizations.dart';
import 'providers/chat_provider.dart';
import 'widgets/chat_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final isLoading = ref.read(chatLoadingProvider);
    if (isLoading) return;

    _controller.clear();

    final locale = Localizations.localeOf(context).languageCode;
    await ref.read(chatMessagesProvider.notifier).sendMessage(text, locale);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messages = ref.watch(chatMessagesProvider);
    final isLoading = ref.watch(chatLoadingProvider);
    final cs = context.colors;
    final isDark = context.isDark;

    // Auto-scroll when messages change
    if (messages.isNotEmpty) _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.dustyTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.chatTitle,
              style: context.textTheme.titleMedium,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messages.isEmpty
                ? _buildWelcome(l10n, cs, isDark)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length && isLoading) {
                        return _buildTypingIndicator(isDark);
                      }
                      return ChatBubble(message: messages[index]);
                    },
                  ),
          ),

          // Input field
          _buildInput(l10n, cs, isDark, isLoading),
        ],
      ),
    );
  }

  Widget _buildWelcome(AppLocalizations l10n, ColorScheme cs, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.dustyTeal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.dustyTeal,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.chatWelcomeTitle,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chatWelcomeSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 13,
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            // Suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _suggestionChip(l10n.chatSuggestion1, isDark),
                _suggestionChip(l10n.chatSuggestion2, isDark),
                _suggestionChip(l10n.chatSuggestion3, isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String text, bool isDark) {
    return ActionChip(
      label: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Sora',
          fontSize: 12,
          color: AppColors.dustyTeal,
        ),
      ),
      backgroundColor: isDark
          ? AppColors.darkSurfaceHigh
          : AppColors.dustyTealLight,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        _controller.text = text;
        _send();
      },
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 48, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceHigh : AppColors.surfaceElevated,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(0),
            const SizedBox(width: 4),
            _dot(1),
            const SizedBox(width: 4),
            _dot(2),
          ],
        ),
      ),
    );
  }

  Widget _dot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + index * 200),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.dustyTeal.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput(
    AppLocalizations l10n,
    ColorScheme cs,
    bool isDark,
    bool isLoading,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        8,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorderColor : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              maxLines: 3,
              minLines: 1,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 14,
                color: isDark ? AppColors.darkText : AppColors.textDark,
              ),
              decoration: InputDecoration(
                hintText: l10n.chatPlaceholder,
                hintStyle: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textSubtle,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.darkBorderColor
                        : AppColors.borderLight,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.darkBorderColor
                        : AppColors.borderLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: AppColors.dustyTeal,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: isLoading ? null : _send,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.dustyTeal,
                    ),
                  )
                : const Icon(
                    Icons.send_rounded,
                    color: AppColors.dustyTeal,
                  ),
          ),
        ],
      ),
    );
  }
}
