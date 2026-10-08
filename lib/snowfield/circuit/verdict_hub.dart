import 'dart:convert';

import '../dossier/client_dossier.dart';
import '../trail/step_verdict.dart';
import 'aurora_vault.dart';
import 'wire_courier.dart';

// ============================================================
//  VerdictHub — POST the body, cache the answer
// ============================================================
//  The backend is the single source of truth for routing. On an
//  approved reply we cache both the URL and its expiry so a
//  returning boot can skip the network call entirely while the
//  cache stays fresh. On any failure we return a rejected verdict
//  — the director turns that into either a game or an offline
//  landing depending on prior state.
// ============================================================

class VerdictHub {
  VerdictHub(this._vault);

  final AuroraVault _vault;

  Future<VerdictReply> query(Map<String, dynamic> body) async {
    final String endpoint = ClientDossier.verdictEndpoint;
    if (endpoint.isEmpty) {
      return VerdictReply.rejected('endpoint_missing');
    }

    try {
      final dynamic response = await wireCourier
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: ClientDossier.verdictTimeoutSec));

      if (response.statusCode != 200) {
        return VerdictReply.rejected('http_${response.statusCode}');
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) return VerdictReply.rejected('malformed');
      final VerdictReply reply = VerdictReply.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      if (reply.hasTarget) {
        await _vault.stashTarget(reply.target!, reply.freshUntil);
      }
      return reply;
    } catch (e) {
      return VerdictReply.rejected('net:$e');
    }
  }
}
