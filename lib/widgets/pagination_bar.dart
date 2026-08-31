import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bottom pagination bar: first / prev / page / of N / next / last plus a
/// record-range label. Mirrors the gd_college pagination bar.
class PaginationBar extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final int pageSize;
  final bool isLoading;
  final ValueChanged<int> onPageChanged;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    required this.pageSize,
    this.isLoading = false,
    required this.onPageChanged,
  });

  @override
  State<PaginationBar> createState() => _PaginationBarState();
}

class _PaginationBarState extends State<PaginationBar> {
  final TextEditingController _input = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _go(int page) {
    if (page < 1 || page > widget.totalPages) return;
    if (page != widget.currentPage) widget.onPageChanged(page);
  }

  void _submit() {
    final page = int.tryParse(_input.text);
    if (page != null) _go(page);
    setState(() => _editing = false);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 480;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isNarrow) ...[
            Text(_rangeLabel(),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(width: 16),
          ],
          _NavBtn(
            icon: Icons.first_page,
            tooltip: 'First page',
            enabled: widget.currentPage > 1 && !widget.isLoading,
            onTap: () => _go(1),
          ),
          _NavBtn(
            icon: Icons.chevron_left,
            tooltip: 'Previous',
            enabled: widget.currentPage > 1 && !widget.isLoading,
            onTap: () => _go(widget.currentPage - 1),
          ),
          const SizedBox(width: 6),
          _editing
              ? SizedBox(
                  width: 60,
                  height: 32,
                  child: TextField(
                    controller: _input,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: Color(0xFF1A3C6E)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: Color(0xFF1A3C6E), width: 2),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                    onTapOutside: (_) => setState(() => _editing = false),
                  ),
                )
              : Tooltip(
                  message: 'Tap to jump to a page',
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _editing = true;
                      _input.text = widget.currentPage.toString();
                      _input.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _input.text.length,
                      );
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3C6E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.currentPage}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                  ),
                ),
          const SizedBox(width: 6),
          Text('of ${widget.totalPages}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(width: 6),
          _NavBtn(
            icon: Icons.chevron_right,
            tooltip: 'Next',
            enabled: widget.currentPage < widget.totalPages &&
                !widget.isLoading,
            onTap: () => _go(widget.currentPage + 1),
          ),
          _NavBtn(
            icon: Icons.last_page,
            tooltip: 'Last page',
            enabled: widget.currentPage < widget.totalPages &&
                !widget.isLoading,
            onTap: () => _go(widget.totalPages),
          ),
          if (widget.isLoading) ...[
            const SizedBox(width: 10),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFF1A3C6E)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _rangeLabel() {
    if (widget.totalCount == 0) return 'No records';
    final start = (widget.currentPage - 1) * widget.pageSize + 1;
    final end =
        (start + widget.pageSize - 1).clamp(start, widget.totalCount);
    return '$start–$end of ${widget.totalCount} students';
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _NavBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? const Color(0xFF1A3C6E) : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}
