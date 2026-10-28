import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/shopping_list.dart';
import '../providers/shopping_lists_provider.dart';

Future<ShoppingList?> showShoppingListEditorSheet(
  BuildContext context, {
  ShoppingList? list,
}) {
  return showModalBottomSheet<ShoppingList>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ShoppingListEditorSheet(list: list),
  );
}

class ShoppingListEditorSheet extends ConsumerStatefulWidget {
  const ShoppingListEditorSheet({super.key, this.list});

  final ShoppingList? list;

  @override
  ConsumerState<ShoppingListEditorSheet> createState() =>
      _ShoppingListEditorSheetState();
}

class _ShoppingListEditorSheetState
    extends ConsumerState<ShoppingListEditorSheet> {
  late final TextEditingController _nameController;
  late String _icon;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.list != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.list?.name ?? '');
    _icon = widget.list?.icon ?? shoppingListIcons.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Dê um nome para a lista.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final notifier = ref.read(shoppingListsProvider.notifier);
    final result = _editing
        ? await notifier.updateList(widget.list!.id, name: name, icon: _icon)
        : await notifier.createList(name, icon: _icon);

    if (!mounted) return;
    if (result == null) {
      setState(() {
        _saving = false;
        _error = 'Não foi possível salvar a lista. Tente novamente.';
      });
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _editing ? 'Editar lista' : 'Nova lista',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _editing
                  ? 'Atualize o nome ou o ícone desta lista.'
                  : 'Crie uma lista para cada ocasião: feira, churrasco, atacado...',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppTheme.muted,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              autofocus: !_editing,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: 'Nome da lista',
                hintText: 'Ex.: Feira da Semana',
                counterText: '',
                errorText: _error,
                prefixIcon: const Icon(Icons.edit_note_rounded),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.line),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Ícone da lista',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: shoppingListIcons.map((icon) {
                final selected = icon == _icon;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: 'Ícone $icon',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _icon = icon),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.emeraldTint
                            : AppTheme.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? AppTheme.emerald : AppTheme.line,
                          width: selected ? 1.8 : 1,
                        ),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _editing ? Icons.check_rounded : Icons.add_rounded,
                            size: 19,
                          ),
                    label: Text(
                      _saving
                          ? 'Salvando...'
                          : _editing
                              ? 'Salvar lista'
                              : 'Criar lista',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
