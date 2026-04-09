import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 简单的 API Key 加密/解密
/// 使用机器特征 + 应用标识生成密钥，XOR 加密后 Base64 编码
/// 防止明文存储被直接读取，比裸 JSON 安全得多
class KeyCrypto {
  static String? _cachedKey;

  /// 获取机器派生密钥
  static String _deriveKey() {
    if (_cachedKey != null) return _cachedKey!;
    // 用环境变量组合生成唯一密钥
    final parts = [
      Platform.localHostname,
      Platform.operatingSystemVersion,
      'VibeTasKing_v1', // 应用盐值
      Platform.environment['USERNAME'] ?? Platform.environment['USER'] ?? '',
    ];
    _cachedKey = parts.join('|');
    return _cachedKey!;
  }

  /// 加密字符串
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    final key = _deriveKey();
    final input = utf8.encode(plainText);
    final keyBytes = utf8.encode(key);
    final output = Uint8List(input.length);
    for (var i = 0; i < input.length; i++) {
      output[i] = input[i] ^ keyBytes[i % keyBytes.length];
    }
    return 'ENC:${base64Encode(output)}';
  }

  /// 解密字符串
  static String decrypt(String encrypted) {
    if (encrypted.isEmpty) return '';
    // 兼容旧版明文存储
    if (!encrypted.startsWith('ENC:')) return encrypted;

    final key = _deriveKey();
    final input = base64Decode(encrypted.substring(4));
    final keyBytes = utf8.encode(key);
    final output = Uint8List(input.length);
    for (var i = 0; i < input.length; i++) {
      output[i] = input[i] ^ keyBytes[i % keyBytes.length];
    }
    return utf8.decode(output);
  }
}
