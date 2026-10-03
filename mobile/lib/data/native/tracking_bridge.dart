import 'package:flutter/foundation.dart';

import 'vapen_native.g.dart';

class TrackingBridge extends TrackingFlutterApi {
  TrackingBridge() {
    TrackingFlutterApi.setUp(this);
  }

  final host = TrackingHostApi();
  final trackingState = ValueNotifier<TrackingState?>(null);
  final explorerEvents = ValueNotifier<List<ExplorerEvent>>([]);

  @override
  void onTrackingStateChanged(TrackingState state) {
    trackingState.value = state;
  }

  @override
  void onPuff(PuffInfo puff) {}

  @override
  void onStatus(StatusInfo status) {}

  @override
  void onExplorerEvent(ExplorerEvent event) {
    final list = List<ExplorerEvent>.from(explorerEvents.value);
    list.add(event);
    explorerEvents.value = list;
  }
}
