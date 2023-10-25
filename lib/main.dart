import 'dart:convert';
// import 'dart:html';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'WebRTC lets learn together'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _offer = false;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();

  final sdpController = TextEditingController();

  @override
  dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    sdpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    initRenderer();
    _createPeerConnecion().then((pc) {
      _peerConnection = pc;
    });
    // _getUserMedia();
    super.initState();
  }

  initRenderer() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  _createPeerConnecion() async {
    Map<String, dynamic> configuration = {
      "sdpSemantics": "plan-b",
      "iceServers": [
        {"url": "stun:stun.2talk.co.nz:3478"},
        {
          "urls": ["turn:3.208.30.246:3478"],
          "username": "turnuserlgmk",
          "credential": "turn456",
        },
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    _localStream = await _getUserMedia();

    RTCPeerConnection pc =
        await createPeerConnection(configuration, offerSdpConstraints);

    pc.addStream(_localStream!);

    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMLineIndex,
        }));
      }
    };

    pc.onIceConnectionState = (e) {
      print(e);
    };

    pc.onAddStream = (stream) {
      print('addStream: ' + stream.id);
      _remoteRenderer.srcObject = stream;
    };

    return pc;
  }

  _getUserMedia() async {
    final Map<String, dynamic> constraints = {
      'audio': false,
      'video': {
        'facingMode': 'user',
      },
    };

    MediaStream stream = await navigator.mediaDevices.getUserMedia(constraints);

    _localRenderer.srcObject = stream;
    // _localRenderer.mirror = true;

    return stream;
  }

  void _createOffer() async {
    RTCSessionDescription description =
        await _peerConnection!.createOffer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp.toString());
    var infoOffer = json.encode(session);

    print("infoOffer $infoOffer");

    _offer = true;

    // print(json.encode({
    //       'sdp': description.sdp.toString(),
    //       'type': description.type.toString(),
    //     }));

    _peerConnection!.setLocalDescription(description);
  }

  void _createAnswer() async {
    RTCSessionDescription description =
        await _peerConnection!.createAnswer({'offerToReceiveVideo': 1});

    var session = parse(description.sdp.toString());

    var infoAnswer = json.encode(session);

    print("infoAnswer $infoAnswer");
    // print(json.encode({
    //       'sdp': description.sdp.toString(),
    //       'type': description.type.toString(),
    //     }));

    _peerConnection!.setLocalDescription(description);
  }

  void _setRemoteDescription() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');

    String sdp = write(session, null);

    // RTCSessionDescription description =
    //     new RTCSessionDescription(session['sdp'], session['type']);
    RTCSessionDescription description =
        new RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    print(description.toMap());

    await _peerConnection!.setRemoteDescription(description);
  }

  void _addCandidate() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');
    print(session['candidate']);
    dynamic candidate = new RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection!.addCandidate(candidate);
  }

  SizedBox videoRenderers() => SizedBox(
      height: 210,
      child: Row(children: [
        Flexible(
          child: new Container(
              height: 140,
              width: 140,
              key: new Key("local"),
              margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: new BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_localRenderer)),
        ),
        Flexible(
          child: new Container(
              height: 140,
              width: 140,
              key: new Key("remote"),
              margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: new BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_remoteRenderer)),
        )
      ]));

  Row offerAndAnswerButtons() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
        new ElevatedButton(
          // onPressed: () {
          //   return showDialog(
          //       context: context,
          //       builder: (context) {
          //         return AlertDialog(
          //           content: Text(sdpController.text),
          //         );
          //       });
          // },
          onPressed: _createOffer,
          child: Text('Offer'),
          // color: Colors.amber,
        ),
        ElevatedButton(
          onPressed: _createAnswer,
          child: Text('Answer'),
          style: ElevatedButton.styleFrom(primary: Colors.amber),
        ),
      ]);

  Row sdpCandidateButtons() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
        ElevatedButton(
          onPressed: _setRemoteDescription,
          child: Text('Set Remote Desc'),
          // color: Colors.amber,
        ),
        ElevatedButton(
          onPressed: _addCandidate,
          child: Text('Add Candidate'),
          // color: Colors.amber,
        )
      ]);

  Padding sdpCandidatesTF() => Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: sdpController,
          keyboardType: TextInputType.multiline,
          maxLines: 4,
          maxLength: TextField.noMaxLength,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Container(
            child: Container(
                child: Column(
          children: [
            videoRenderers(),
            offerAndAnswerButtons(),
            sdpCandidatesTF(),
            sdpCandidateButtons(),
          ],
        ))
            // new Stack(
            //   children: [
            //     new Positioned(
            //       top: 0.0,
            //       right: 0.0,
            //       left: 0.0,
            //       bottom: 0.0,
            //       child: new Container(
            //         child: new RTCVideoView(_localRenderer)
            //       )
            //     )
            //   ],
            // ),
            ));
  }
}

// import 'dart:convert';
// // import 'dart:html';

// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:sdp_transform/sdp_transform.dart';
// import 'package:flutter/services.dart';

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       home: MyHomePage(title: 'WebRTC lets learn together'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   MyHomePage({Key? key, required this.title}) : super(key: key);

//   final String title;

//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   bool _offer = false;
//   RTCPeerConnection? _peerConnection;
//   MediaStream? _localStream;
//   RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
//   RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();

//   final sdpController = TextEditingController();
//   final sdpController2 = TextEditingController();
//   final candidatesController = TextEditingController();

//   @override
//   dispose() {
//     _localRenderer.dispose();
//     _remoteRenderer.dispose();
//     sdpController.dispose();
//     sdpController2.dispose();
//     candidatesController.dispose();

//     super.dispose();
//   }

//   @override
//   void initState() {
//     initRenderer();
//     _createPeerConnecion().then((pc) {
//       _peerConnection = pc;
//     });
//     // _getUserMedia();
//     super.initState();
//   }

//   initRenderer() async {
//     await _localRenderer.initialize();
//     await _remoteRenderer.initialize();
//   }

//   _createPeerConnecion() async {
//     Map<String, dynamic> configuration = {
//       "sdpSemantics": "plan-b",
//       "iceServers": [
//         {"url": "stun:stun.l.google.com:19302"},
//       ]
//     };

//     final Map<String, dynamic> offerSdpConstraints = {
//       "mandatory": {
//         "OfferToReceiveAudio": true,
//         "OfferToReceiveVideo": true,
//       },
//       "optional": [],
//     };

//     _localStream = await _getUserMedia();

//     RTCPeerConnection pc =
//         await createPeerConnection(configuration, offerSdpConstraints);

//     pc.addStream(_localStream!);

//     pc.onIceCandidate = (e) {
//       if (e.candidate != null) {
//         candidatesController.text = json.encode({
//           'candidate': e.candidate.toString(),
//           'sdpMid': e.sdpMid.toString(),
//           'sdpMlineIndex': e.sdpMLineIndex,
//         });
//         print(json.encode({
//           'candidate': e.candidate.toString(),
//           'sdpMid': e.sdpMid.toString(),
//           'sdpMlineIndex': e.sdpMLineIndex,
//         }));
//       }
//     };

//     pc.onIceConnectionState = (e) {
//       print(e);
//     };

//     pc.onAddStream = (stream) {
//       print('addStream: ' + stream.id);
//       _remoteRenderer.srcObject = stream;
//     };

//     return pc;
//   }

//   _getUserMedia() async {
//     final Map<String, dynamic> constraints = {
//       'audio': false,
//       'video': {
//         'facingMode': 'user',
//       },
//     };

//     MediaStream stream = await navigator.mediaDevices.getUserMedia(constraints);

//     _localRenderer.srcObject = stream;
//     // _localRenderer.mirror = true;

//     return stream;
//   }

//   void _createOffer() async {
//     RTCSessionDescription description =
//         await _peerConnection!.createOffer({'offerToReceiveVideo': 1});
//     var session = parse(description.sdp.toString());
//     sdpController2.text = json.encode(session);
//     print(json.encode(session));
//     _offer = true;

//     // print(json.encode({
//     //       'sdp': description.sdp.toString(),
//     //       'type': description.type.toString(),
//     //     }));

//     _peerConnection!.setLocalDescription(description);
//   }

//   void _createAnswer() async {
//     RTCSessionDescription description =
//         await _peerConnection!.createAnswer({'offerToReceiveVideo': 1});

//     var session = parse(description.sdp.toString());
//     sdpController2.text = json.encode(session);

//     print(json.encode(session));
//     // print(json.encode({
//     //       'sdp': description.sdp.toString(),
//     //       'type': description.type.toString(),
//     //     }));

//     _peerConnection!.setLocalDescription(description);
//   }

//   void _setRemoteDescription() async {
//     String jsonString = sdpController.text;
//     dynamic session = await jsonDecode('$jsonString');

//     String sdp = write(session, null);

//     // RTCSessionDescription description =
//     //     new RTCSessionDescription(session['sdp'], session['type']);
//     RTCSessionDescription description =
//         new RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');

//     print("description from setremote ${description.toMap()}");

//     var session2 = parse(description.sdp.toString());
//     sdpController2.text = json.encode(session2);
//     await _peerConnection!.setRemoteDescription(description);
//   }

//   void _addCandidate() async {
//     String jsonString = sdpController.text;
//     dynamic session = await jsonDecode('$jsonString');
//     print(session['candidate']);
//     dynamic candidate = new RTCIceCandidate(
//         session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
//     await _peerConnection!.addCandidate(candidate);
//   }

//   void _copyToClipboard(
//     String text,
//     BuildContext context,
//   ) {
//     Clipboard.setData(ClipboardData(text: text));
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Monda copiada exitosamente'),
//       ),
//     );
//   }

//   SizedBox videoRenderers() => SizedBox(
//       height: 210,
//       child: Row(children: [
//         Flexible(
//           child: new Container(
//               key: new Key("local"),
//               margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
//               decoration: new BoxDecoration(color: Colors.black),
//               child: new RTCVideoView(_localRenderer)),
//         ),
//         Flexible(
//           child: new Container(
//               key: new Key("remote"),
//               margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
//               decoration: new BoxDecoration(color: Colors.black),
//               child: new RTCVideoView(_remoteRenderer)),
//         )
//       ]));

//   Row offerAndAnswerButtons() =>
//       Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
//         new ElevatedButton(
//           // onPressed: () {
//           //   return showDialog(
//           //       context: context,
//           //       builder: (context) {
//           //         return AlertDialog(
//           //           content: Text(sdpController.text),
//           //         );
//           //       });
//           // },
//           onPressed: _createOffer,
//           child: Text('Offer'),
//           // color: Colors.amber,
//         ),
//         ElevatedButton(
//           onPressed: _createAnswer,
//           child: Text('Answer'),
//           style: ElevatedButton.styleFrom(primary: Colors.amber),
//         ),
//       ]);

//   Row sdpCandidateButtons() =>
//       Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
//         ElevatedButton(
//           onPressed: _setRemoteDescription,
//           child: Text('Set Remote Desc'),
//           // color: Colors.amber,
//         ),
//         ElevatedButton(
//           onPressed: _addCandidate,
//           child: Text('Add Candidate'),
//           // color: Colors.amber,
//         )
//       ]);

//   Padding sdpCandidatesTF() => Padding(
//         padding: const EdgeInsets.all(2.0),
//         child: TextField(
//           controller: sdpController,
//           keyboardType: TextInputType.multiline,
//           maxLines: 2,
//           maxLength: TextField.noMaxLength,
//         ),
//       );
//   Padding sdpInfo() => Padding(
//         padding: const EdgeInsets.all(2.0),
//         child: TextField(
//           controller: sdpController2,
//           keyboardType: TextInputType.multiline,
//           maxLines: 3,
//           maxLength: TextField.noMaxLength,
//         ),
//       );
//   Padding candidateInfo() => Padding(
//         padding: const EdgeInsets.all(2.0),
//         child: TextField(
//           controller: candidatesController,
//           keyboardType: TextInputType.multiline,
//           maxLines: 3,
//           maxLength: TextField.noMaxLength,
//         ),
//       );
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//           title: Text(widget.title),
//         ),
//         body: Container(
//             child: Container(
//                 child: Column(
//           children: [
//             videoRenderers(),
//             offerAndAnswerButtons(),
//             sdpCandidatesTF(),
//             sdpCandidateButtons(),
//             sdpInfo(),
//             ElevatedButton(
//               onPressed: () {
//                 _copyToClipboard(sdpController2.text, context);
//               },
//               child: Text('Copiar esa monda'),
//             ),
//             candidateInfo(),
//             ElevatedButton(
//               onPressed: () {
//                 _copyToClipboard(candidatesController.text, context);
//               },
//               child: Text('Copiar esa monda'),
//             ),
//           ],
//         ))
//             // new Stack(
//             //   children: [
//             //     new Positioned(
//             //       top: 0.0,
//             //       right: 0.0,
//             //       left: 0.0,
//             //       bottom: 0.0,
//             //       child: new Container(
//             //         child: new RTCVideoView(_localRenderer)
//             //       )
//             //     )
//             //   ],
//             // ),
//             ));
//   }
// }
// import 'dart:convert';
// // import 'dart:html';

// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:sdp_transform/sdp_transform.dart';

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       home: MyHomePage(title: 'prueba manual'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   MyHomePage({Key? key, required this.title}) : super(key: key);

//   final String title;

//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   bool _offer = false;
//   RTCPeerConnection? _peerConnection;
//   MediaStream? _localStream;
//   RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
//   RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();

//   final sdpController = TextEditingController();
//   final sdpController2 = TextEditingController();

//   @override
//   dispose() {
//     _localRenderer.dispose();
//     _remoteRenderer.dispose();
//     sdpController.dispose();
//     sdpController2.dispose();

//     super.dispose();
//   }

//   @override
//   void initState() {
//     initRenderer();
//     _createPeerConnecion().then((pc) {
//       _peerConnection = pc;
//     });
//     // _getUserMedia();
//     super.initState();
//   }

//   initRenderer() async {
//     await _localRenderer.initialize();
//     await _remoteRenderer.initialize();
//   }

//   _createPeerConnecion() async {
//     final configuration = <String, dynamic>{
//       "sdpSemantics": "plan-b",
//       'iceServers': [
//         {"url": "stun:stun.l.google.com:19302"},
//         // {
//         //   "urls": [
//         //     "turn:3.208.30.246:3478" // fusionpbx
//         //   ],

//         //   "username": "turnuserlgmk", //fusionpbx
//         //   "credential": "turn456"
//         // },
//       ],
//       // 'sdpSemantics': "unified-plan",
//       // 'encodedInsertableStreams': true,
//     };

//     // Map<String, dynamic> configuration = {
//     //   "iceServers": [
//     //     {"url": "stun:stun.l.google.com:19302"},
//     //   ]
//     // };

//     final Map<String, dynamic> offerSdpConstraints = {
//       "mandatory": {
//         "OfferToReceiveAudio": true,
//         "OfferToReceiveVideo": true,
//       },
//       "optional": [],
//     };

//     _localStream = await _getUserMedia();

//     RTCPeerConnection pc =
//         await createPeerConnection(configuration, offerSdpConstraints);

//     pc.addStream(_localStream!);

//     pc.onIceCandidate = (e) {
//       if (e.candidate != null) {
//         print(json.encode({
//           'candidate': e.candidate.toString(),
//           'sdpMid': e.sdpMid.toString(),
//           'sdpMlineIndex': e.sdpMLineIndex
//         }));
//       }
//     };

//     pc.onIceConnectionState = (e) {
//       print(e);
//     };

//     pc.onAddStream = (stream) {
//       print('addStream: ' + stream.id);
//       _remoteRenderer.srcObject = stream;
//     };

//     return pc;
//   }

//   _getUserMedia() async {
//     final Map<String, dynamic> constraints = {
//       'audio': false,
//       'video': {
//         'facingMode': 'user',
//       },
//     };

//     MediaStream stream = await navigator.mediaDevices.getUserMedia(constraints);

//     _localRenderer.srcObject = stream;
//     // _localRenderer.mirror = true;

//     return stream;
//   }

//   void _createOffer() async {
//     RTCSessionDescription description =
//         await _peerConnection!.createOffer({'offerToReceiveVideo': 1});
//     var session = parse(description.sdp.toString());
//     print('sdp info ${json.encode(session)}');
//     sdpController2.text = json.encode(session);
//     _offer = true;

//     // print(json.encode({
//     //       'sdp': description.sdp.toString(),
//     //       'type': description.type.toString(),
//     //     }));

//     _peerConnection!.setLocalDescription(description);
//   }

//   void _createAnswer() async {
//     RTCSessionDescription description =
//         await _peerConnection!.createAnswer({'offerToReceiveVideo': 1});

//     var session = parse(description.sdp.toString());
//     print(json.encode(session));
//     // print(json.encode({
//     //       'sdp': description.sdp.toString(),
//     //       'type': description.type.toString(),
//     //     }));

//     _peerConnection!.setLocalDescription(description);
//   }

//   void _setRemoteDescription() async {
//     String jsonString = sdpController.text;
//     dynamic session = await jsonDecode('$jsonString');

//     String sdp = write(session, null);

//     // RTCSessionDescription description =
//     //     new RTCSessionDescription(session['sdp'], session['type']);
//     RTCSessionDescription description =
//         new RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
//     print(description.toMap());

//     await _peerConnection!.setRemoteDescription(description);
//   }

//   void _addCandidate() async {
//     String jsonString = sdpController.text;
//     dynamic session = await jsonDecode('$jsonString');
//     print(session['candidate']);
//     dynamic candidate = new RTCIceCandidate(
//         session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
//     await _peerConnection!.addCandidate(candidate);
//   }

//   SizedBox videoRenderers() => SizedBox(
//       height: 210,
//       child: Row(children: [
//         Flexible(
//           child: new Container(
//               height: 110,
//               width: 110,
//               key: new Key("local"),
//               margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
//               decoration: new BoxDecoration(color: Colors.black),
//               child: new RTCVideoView(_localRenderer)),
//         ),
//         Flexible(
//           child: new Container(
//               height: 180,
//               width: 180,
//               key: new Key("remote"),
//               margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
//               decoration: new BoxDecoration(color: Colors.black),
//               child: new RTCVideoView(_remoteRenderer)),
//         )
//       ]));

//   Row offerAndAnswerButtons() =>
//       Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
//         new ElevatedButton(
//           // onPressed: () {
//           //   return showDialog(
//           //       context: context,
//           //       builder: (context) {
//           //         return AlertDialog(
//           //           content: Text(sdpController.text),
//           //         );
//           //       });
//           // },
//           onPressed: _createOffer,
//           child: Text('Crear sala'),
//           // color: Colors.amber,
//         ),
//         ElevatedButton(
//           onPressed: _createAnswer,
//           child: Text('Unirse sala'),
//           style: ElevatedButton.styleFrom(primary: Colors.amber),
//         ),
//       ]);

//   Row sdpCandidateButtons() =>
//       Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
//         ElevatedButton(
//           onPressed: _setRemoteDescription,
//           child: Text('Set sdp '),
//           // color: Colors.amber,
//         ),
//         ElevatedButton(
//           onPressed: _addCandidate,
//           child: Text('set candidate'),
//           // color: Colors.amber,
//         )
//       ]);

//   Padding sdpCandidatesTF() => Padding(
//         padding: const EdgeInsets.all(2.0),
//         child: TextField(
//           controller: sdpController,
//           keyboardType: TextInputType.multiline,
//           maxLines: 2,
//           maxLength: TextField.noMaxLength,
//         ),
//       );
//   Padding sdpInfo() => Padding(
//         padding: const EdgeInsets.all(2.0),
//         child: TextField(
//           controller: sdpController2,
//           keyboardType: TextInputType.multiline,
//           maxLines: 12,
//           maxLength: TextField.noMaxLength,
//         ),
//       );
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//           title: Text(widget.title),
//         ),
//         body: Container(
//             child: Container(
//                 child: Column(
//           children: [
//             videoRenderers(),
//             offerAndAnswerButtons(),
//             sdpCandidatesTF(),
//             sdpCandidateButtons(),
//             sdpInfo()
//           ],
//         ))
//             // new Stack(
//             //   children: [
//             //     new Positioned(
//             //       top: 0.0,
//             //       right: 0.0,
//             //       left: 0.0,
//             //       bottom: 0.0,
//             //       child: new Container(
//             //         child: new RTCVideoView(_localRenderer)
//             //       )
//             //     )
//             //   ],
//             // ),
//             ));
//   }
// }
