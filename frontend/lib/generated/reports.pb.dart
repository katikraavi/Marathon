/// Protobuf messages generated from reports.proto
/// Simplified non-GeneratedMessage implementation for compatibility

/// Time-based vital report sent every second
class TimeBasedReport {
  final int deviceId;
  final int timestamp;
  final int distance;
  final List<int> heartbeats;
  final List<int> breaths;

  TimeBasedReport({
    required this.deviceId,
    required this.timestamp,
    required this.distance,
    required this.heartbeats,
    required this.breaths,
  });

  /// Deserialize from protobuf binary format
  static TimeBasedReport fromBuffer(List<int> buffer) {
    int deviceId = 0;
    int timestamp = 0;
    int distance = 0;
    List<int> heartbeats = [];
    List<int> breaths = [];

    int pos = 0;
    while (pos < buffer.length) {
      int byte = buffer[pos];
      int fieldNumber = byte >> 3;
      int wireType = byte & 0x07;
      pos++;

      if (wireType == 0) {
        // Varint
        int value = 0;
        int shift = 0;
        while (true) {
          int b = buffer[pos++];
          value |= (b & 0x7F) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }

        if (fieldNumber == 1) {
          deviceId = value;
        } else if (fieldNumber == 2) {
          timestamp = value;
        } else if (fieldNumber == 3) {
          distance = value;
        }
      } else if (wireType == 2) {
        // Length-delimited
        int length = 0;
        int shift = 0;
        while (true) {
          int b = buffer[pos++];
          length |= (b & 0x7F) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }

        if (fieldNumber == 4) {
          // heartbeats
          for (int i = 0; i < length; i += 8) {
            if (i + 8 <= length) {
              heartbeats.add(_readInt64(buffer, pos + i));
            }
          }
          pos += length;
        } else if (fieldNumber == 5) {
          // breaths
          for (int i = 0; i < length; i += 8) {
            if (i + 8 <= length) {
              breaths.add(_readInt64(buffer, pos + i));
            }
          }
          pos += length;
        } else {
          pos += length;
        }
      }
    }

    return TimeBasedReport(
      deviceId: deviceId,
      timestamp: timestamp,
      distance: distance,
      heartbeats: heartbeats,
      breaths: breaths,
    );
  }
}

/// Event-based vital report for BP, O2, or temperature changes
class EventBasedReport {
  final int deviceId;
  final int timestamp;
  final int eventId;
  final List<int> eventData;

  EventBasedReport({
    required this.deviceId,
    required this.timestamp,
    required this.eventId,
    required this.eventData,
  });

  /// Deserialize from protobuf binary format
  static EventBasedReport fromBuffer(List<int> buffer) {
    int deviceId = 0;
    int timestamp = 0;
    int eventId = 0;
    List<int> eventData = [];

    int pos = 0;
    while (pos < buffer.length) {
      int byte = buffer[pos];
      int fieldNumber = byte >> 3;
      int wireType = byte & 0x07;
      pos++;

      if (wireType == 0) {
        // Varint
        int value = 0;
        int shift = 0;
        while (true) {
          int b = buffer[pos++];
          value |= (b & 0x7F) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }

        if (fieldNumber == 1) {
          deviceId = value;
        } else if (fieldNumber == 2) {
          timestamp = value;
        } else if (fieldNumber == 3) {
          eventId = value;
        }
      } else if (wireType == 2) {
        // Length-delimited
        int length = 0;
        int shift = 0;
        while (true) {
          int b = buffer[pos++];
          length |= (b & 0x7F) << shift;
          if ((b & 0x80) == 0) break;
          shift += 7;
        }

        if (fieldNumber == 4) {
          // eventData
          int endPos = pos + length;
          while (pos < endPos) {
            int value = 0;
            int s = 0;
            while (true) {
              int b = buffer[pos++];
              value |= (b & 0x7F) << s;
              if ((b & 0x80) == 0) break;
              s += 7;
            }
            eventData.add(value);
          }
        } else {
          pos += length;
        }
      }
    }

    return EventBasedReport(
      deviceId: deviceId,
      timestamp: timestamp,
      eventId: eventId,
      eventData: eventData,
    );
  }
}

// Helper function
int _readInt64(List<int> buffer, int offset) {
  int value = 0;
  for (int i = 0; i < 8; i++) {
    value |= buffer[offset + i] << (i * 8);
  }
  return value;
}
