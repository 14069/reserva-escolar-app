import '../utils/json_utils.dart';
import 'notification_metadata_model.dart';

class NotificationModel {
  final int id;
  final String type;
  final String title;
  final String message;
  final int? bookingId;
  final NotificationMetadataModel? metadata;
  final String? readAt;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.bookingId,
    this.metadata,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    final parsedMetadata = rawMetadata is Map<String, dynamic>
        ? NotificationMetadataModel.fromJson(rawMetadata)
        : rawMetadata is Map
        ? NotificationMetadataModel.fromJson(
            rawMetadata.cast<String, dynamic>(),
          )
        : null;

    return NotificationModel(
      id: parseJsonInt(json['id']),
      type: parseJsonString(json['type']),
      title: parseJsonString(json['title']),
      message: parseJsonString(json['message']),
      bookingId:
          parseJsonIntOrNull(json['booking_id']) ?? parsedMetadata?.bookingId,
      metadata: parsedMetadata,
      readAt: parseJsonStringOrNull(json['read_at']),
      createdAt: parseJsonString(json['created_at']),
    );
  }

  bool get isRead => (readAt ?? '').isNotEmpty;

  NotificationModel copyWith({
    int? id,
    String? type,
    String? title,
    String? message,
    Object? bookingId = _notificationModelSentinel,
    Object? metadata = _notificationModelSentinel,
    Object? readAt = _notificationModelSentinel,
    String? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      bookingId: identical(bookingId, _notificationModelSentinel)
          ? this.bookingId
          : bookingId as int?,
      metadata: identical(metadata, _notificationModelSentinel)
          ? this.metadata
          : metadata as NotificationMetadataModel?,
      readAt: identical(readAt, _notificationModelSentinel)
          ? this.readAt
          : readAt as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

const Object _notificationModelSentinel = Object();
