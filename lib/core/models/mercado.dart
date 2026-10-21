import 'package:equatable/equatable.dart';

/// Mercado identificado para uma compra.
///
/// `isRemoto` distingue um mercado persistido no Supabase de um cadastro
/// criado localmente quando o app está sem conexão. A compra sempre guarda o
/// nome; o `id` remoto só é enviado à nuvem quando existe.
class Mercado extends Equatable {
  final String id;
  final String nome;
  final double? latitude;
  final double? longitude;
  final double? distanciaMetros;
  final String? endereco;
  final String? cidade;
  final String? bairro;
  final String? chain;
  final bool verificado;
  final bool isRemoto;

  const Mercado({
    required this.id,
    required this.nome,
    this.latitude,
    this.longitude,
    this.distanciaMetros,
    this.endereco,
    this.cidade,
    this.bairro,
    this.chain,
    this.verificado = false,
    this.isRemoto = true,
  });

  bool get temCoordenadas => latitude != null && longitude != null;

  String? get localLabel {
    final parts = <String>[
      if (bairro != null && bairro!.trim().isNotEmpty) bairro!.trim(),
      if (cidade != null && cidade!.trim().isNotEmpty) cidade!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' • ');
  }

  String? get distanciaLabel {
    final meters = distanciaMetros;
    if (meters == null) return null;
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  factory Mercado.fromRpc(Map<String, dynamic> json) {
    return Mercado(
      id: json['id'] as String,
      nome: (json['nome'] ?? json['name'] ?? 'Mercado') as String,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      distanciaMetros: _toDouble(json['distancia_metros']),
      endereco: json['endereco'] as String? ?? json['address'] as String?,
      cidade: json['cidade'] as String?,
      bairro: json['bairro'] as String?,
      chain: json['chain'] as String?,
      verificado: (json['verificado'] ?? json['verified'] ?? false) as bool,
      isRemoto: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'latitude': latitude,
        'longitude': longitude,
        'distancia_metros': distanciaMetros,
        'endereco': endereco,
        'cidade': cidade,
        'bairro': bairro,
        'chain': chain,
        'verificado': verificado,
        'is_remoto': isRemoto,
      };

  Mercado copyWith({
    String? id,
    String? nome,
    double? latitude,
    double? longitude,
    double? distanciaMetros,
    String? endereco,
    String? cidade,
    String? bairro,
    String? chain,
    bool? verificado,
    bool? isRemoto,
  }) {
    return Mercado(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanciaMetros: distanciaMetros ?? this.distanciaMetros,
      endereco: endereco ?? this.endereco,
      cidade: cidade ?? this.cidade,
      bairro: bairro ?? this.bairro,
      chain: chain ?? this.chain,
      verificado: verificado ?? this.verificado,
      isRemoto: isRemoto ?? this.isRemoto,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [
        id,
        nome,
        latitude,
        longitude,
        distanciaMetros,
        endereco,
        cidade,
        bairro,
        chain,
        verificado,
        isRemoto,
      ];
}
