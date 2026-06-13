import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

void main() {
  test('Test BlurHash decoding of all custom hashes', () {
    final hashes = [
      'L6PZ|Ye.dCp000]y%gBx_NixRj%m', // Green
      'L5H2EC=y00?G00ngObxo00Ry_~%L', // Blue
      'LJH2aH_2_3xZ~q?b-;of9F%M%Mxa', // Purple
      'LNH2yG_3_3%M~q_2Mx-;4m%M%M%M', // Orange
      'L48z4E004m_w_wt7t7_w00D%_1xa', // Teal
      'LKN]~^%hDh-p.gDUxaMj00%MIpkW', // Gold/Amber
      'LEHV6nWB2yk8pyo0adR*.7kCMdnj', // Default Gray
    ];

    for (final hash in hashes) {
      print('Testing hash: $hash');
      final image = blurHashDecode(blurHash: hash, width: 32, height: 32);
      expect(image, isNotNull);
      print('Successfully decoded hash: $hash');
    }
  });
}
