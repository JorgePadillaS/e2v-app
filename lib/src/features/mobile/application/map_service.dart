import 'package:url_launcher/url_launcher.dart';

class MapService {
  /// Opens the native map application (Google Maps, Waze, Apple Maps)
  /// using the provided latitude and longitude.
  static Future<void> navigateTo(double lat, double lng, {String? googleMapsUrl}) async {
    // 1. Try Direct URL first (usually universal)
    if (googleMapsUrl != null && googleMapsUrl.isNotEmpty) {
      final directUri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(directUri)) {
        await launchUrl(directUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // 2. Try Google Maps Native Intent (Best for Android)
    final googleNavUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');

    // 3. Try Waze
    final wazeUri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');

    // 4. Try Generic Geo URI
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng(Cargador+MaxVolt)');

    // 5. Hard Fallback Browser Link
    final fallbackHttpUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(googleNavUri)) {
        await launchUrl(googleNavUri);
      } else if (await canLaunchUrl(wazeUri)) {
        await launchUrl(wazeUri);
      } else if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
      } else {
        await launchUrl(fallbackHttpUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await launchUrl(fallbackHttpUri, mode: LaunchMode.externalNonBrowserApplication);
    }
  }
}
