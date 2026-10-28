import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aba ativa da barra inferior. Fica num provider para que atalhos internos
/// (ex.: card da Home) possam navegar para "Minhas Listas" sem acoplar a
/// `AppShell` aos widgets filhos.
final shellTabProvider = StateProvider<int>((ref) => 0);
