import 'package:flutter/material.dart';

import 'app_config.dart';

class BrandingConfig {
  final String platformName;
  final String? logoUrl;
  final BrandingColors branding;
  final LegalConfig legal;
  final List<Promotion> promotions;
  final BusinessPolicies policies;

  BrandingConfig({
    required this.platformName,
    this.logoUrl,
    required this.branding,
    required this.legal,
    required this.promotions,
    required this.policies,
  });

  factory BrandingConfig.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return BrandingConfig(
      platformName: data['platform_name'] ?? 'E2V App',
      logoUrl: data['logo_url'],
      branding: BrandingColors.fromJson(data['branding']),
      legal: LegalConfig.fromJson(data['legal']),
      promotions: (data['promotions'] as List).map((p) => Promotion.fromJson(p)).toList(),
      policies: BusinessPolicies.fromJson(data['policies'] ?? {}),
    );
  }

  // Default config for fallback
  static BrandingConfig get fallback => BrandingConfig(
    platformName: 'E2V App',
    branding: BrandingColors(
      primaryColor: const Color(0xFF0076D6),
      secondaryColor: const Color(0xFF0E4A7B),
      buttonColor: const Color(0xFF0076D6),
      textColor: const Color(0xFF333333),
      fontFamily: 'Manrope',
    ),
    legal: LegalConfig(disclaimerUrl: AppConfig.disclaimerUrl, isDisclaimerVisible: true),
    promotions: [],
    policies: BusinessPolicies(
      invoicingPolicy: 'recharge',
      nitRequirementPolicy: 'optional',
      restrictChargingWithoutVehicle: false,
    ),
  );
}

class BusinessPolicies {
  final String invoicingPolicy; // recharge, usage
  final String nitRequirementPolicy; // optional, required
  final bool restrictChargingWithoutVehicle;

  BusinessPolicies({
    required this.invoicingPolicy,
    required this.nitRequirementPolicy,
    required this.restrictChargingWithoutVehicle,
  });

  factory BusinessPolicies.fromJson(Map<String, dynamic> json) {
    return BusinessPolicies(
      invoicingPolicy: json['invoicing_policy'] ?? 'recharge',
      nitRequirementPolicy: json['nit_requirement_policy'] ?? 'optional',
      restrictChargingWithoutVehicle: json['restrict_charging_without_vehicle'] ?? false,
    );
  }
}

class BrandingColors {
  final Color primaryColor;
  final Color secondaryColor;
  final Color buttonColor;
  final Color textColor;
  final String fontFamily;

  BrandingColors({
    required this.primaryColor,
    required this.secondaryColor,
    required this.buttonColor,
    required this.textColor,
    required this.fontFamily,
  });

  factory BrandingColors.fromJson(Map<String, dynamic> json) {
    return BrandingColors(
      primaryColor: _parseColor(json['primary_color'], const Color(0xFF0076D6)),
      secondaryColor: _parseColor(json['secondary_color'], const Color(0xFF0E4A7B)),
      buttonColor: _parseColor(json['button_color'], const Color(0xFF0076D6)),
      textColor: _parseColor(json['text_color'], const Color(0xFF333333)),
      fontFamily: json['font_family'] ?? 'Manrope',
    );
  }

  static Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}

class LegalConfig {
  final String disclaimerUrl;
  final bool isDisclaimerVisible;

  LegalConfig({required this.disclaimerUrl, required this.isDisclaimerVisible});

  factory LegalConfig.fromJson(Map<String, dynamic> json) {
    return LegalConfig(disclaimerUrl: json['disclaimer_url'] ?? '', isDisclaimerVisible: json['is_disclaimer_visible'] ?? false);
  }
}

class Promotion {
  final int id;
  final String title;
  final String body;
  final String? imageUrl;
  final String type; // push, in_app, alert
  final String frequency;

  Promotion({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.type,
    required this.frequency,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      imageUrl: json['image_url'],
      type: json['type'],
      frequency: json['frequency'],
    );
  }
}
