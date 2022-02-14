/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */

import 'package:google_provider/src/utils/json/json_object.dart';

import 'google_provider_model_email_msg_part.dart';


class GoogleProviderModelEmailMsg extends JsonObject{
  String? id;
  String? threadId;
  List<String>? labelIds;
  String? snippet;
  String? historyId;
  DateTime? internalDate;
  int? sizeEstimate;
  String? raw;
  GoogleProviderModelEmailMsgPart? payload;

  GoogleProviderModelEmailMsg(
      {this.id,
        this.threadId,
        this.labelIds,
        this.snippet,
        this.historyId,
        this.internalDate,
        this.sizeEstimate,
        this.raw,
        this.payload});

  GoogleProviderModelEmailMsg.fromJson(Map<String, dynamic>? json) {
    if (json != null) {
      id = json['id'];
      threadId = json['threadId'];

      if (json['labelIds'] != null) labelIds = List.from(json['labelIds']);

      snippet = json['snippet'];
      historyId = json['historyId'];

      if (json['internalDate'] != null) {
        internalDate = DateTime.fromMillisecondsSinceEpoch(
            int.parse(json['internalDate']));
      }

      sizeEstimate = json['sizeEstimate'];
      raw = json['raw'];
      payload = GoogleProviderModelEmailMsgPart.fromJson(json['payload']);
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'threadId': threadId,
    'labelIds': labelIds,
    'snippet': snippet,
    'historyId': historyId,
    'internalDate': internalDate?.millisecondsSinceEpoch,
    'sizeEstimate': sizeEstimate,
    'raw': raw,
    'payload': payload?.toJson()
  };
}