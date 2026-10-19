import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DioClient {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String get baseUrl {
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://192.168.100.240:3000/api',
    );
  }

  static String resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final serverHost = baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$serverHost$cleanPath';
  }

  static Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Attempt to refresh token
          final refreshToken = await _storage.read(key: 'refresh_token');
          if (refreshToken != null) {
            try {
              final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
              final response = await refreshDio.post('/auth/refresh', data: {
                'refreshToken': refreshToken,
              });

              if (response.statusCode == 200) {
                final newData = response.data;
                final accessToken = newData['accessToken'];
                final newRefreshToken = newData['refreshToken'];

                await _storage.write(key: 'access_token', value: accessToken);
                await _storage.write(key: 'refresh_token', value: newRefreshToken);

                // Retry the original request with new token
                e.requestOptions.headers['Authorization'] = 'Bearer $accessToken';
                final retryResponse = await dio.fetch(e.requestOptions);
                return handler.resolve(retryResponse);
              }
            } catch (refreshError) {
              // Refresh failed, clear tokens only (do not delete biometric device binding)
              await _storage.delete(key: 'access_token');
              await _storage.delete(key: 'refresh_token');
            }
          }
        }
        return handler.next(e);
      },
    ));

    return dio;
  }
}
