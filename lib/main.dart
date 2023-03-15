import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(
    meuApp(),
  );
}

class meuApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: pagina1(),
    );
  }
}

class pagina1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Liga LED"),
      ),
      drawer: Drawer(
        child: menu(),
      ),
      body: Container(
        child: conteudoPagina1(),
      ),
    );
  }
}

class menu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FlutterLogo(),
        Text("Desenvolvido por:"),
        Text("Bruno Rodrigues"),
        Icon(
          Icons.copyright,
        ),
      ],
    );
  }
}

class conteudoPagina1 extends StatefulWidget {
  @override
  State<conteudoPagina1> createState() => _conteudoPagina1State();
}

class _conteudoPagina1State extends State<conteudoPagina1> {
  bool liga = false;
  String mensagem = "";
  String LigaLED = "0";
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            "Liga LED",
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lightbulb_outline,
              ),
              Padding(padding: EdgeInsets.all(10)),
              Icon(
                Icons.lightbulb,
                color: Colors.amber,
              ),
            ],
          ),
          Switch(
              value: liga,
              onChanged: (value) {
                liga = value;
                if (liga) {
                  LigaLED = "1";
                  mensagem = "LED acesso";
                } else {
                  LigaLED = "0";
                  mensagem = "LED apagado";
                }
                setState(() {
                  conectaMQTT();
                });
              }),
          Text(mensagem),
        ],
      ),
    );
  }

  Future<int> conectaMQTT() async {
    final client = MqttServerClient('mqtt.eclipseprojects.io', '');

    /// Set the correct MQTT protocol for mosquito
    client.setProtocolV311();
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.onDisconnected = onDisconnected;
    client.onSubscribed = onSubscribed;
    final connMess = MqttConnectMessage()
        .withClientIdentifier('Mqtt_MyClientUniqueIdQ1')
        .withWillTopic(
            'FIT_bruno') // If you set this you must set a will message
        .withWillMessage('My Will message')
        .startClean() // Non persistent session for testing
        .withWillQos(MqttQos.atLeastOnce);
    print('EXAMPLE::Mosquitto client connecting....');
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } on Exception catch (e) {
      print('EXAMPLE::client exception - $e');
      client.disconnect();
    }

    /// Check we are connected
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('EXAMPLE::Mosquitto client connected');
    } else {
      print(
          'EXAMPLE::ERROR Mosquitto client connection failed - disconnecting, state is ${client.connectionStatus!.state}');
      client.disconnect();
      exit(-1);
    }

    /// Lets try our subscriptions
    print('EXAMPLE:: <<<< SUBSCRIBE 1 >>>>');
    const topic1 = 'FIT_bruno'; // Not a wildcard topic
    client.subscribe(topic1, MqttQos.atLeastOnce);
    print('EXAMPLE:: <<<< SUBSCRIBE 2 >>>>');
    const topic2 = 'FIT_bruno'; // Not a wildcard topic
    client.subscribe(topic2, MqttQos.atLeastOnce);
    const topic3 = 'FIT_bruno'; // Not a wildcard topic - no subscription

    client.updates!.listen((messageList) {
      final recMess = messageList[0];
      if (recMess is! MqttReceivedMessage<MqttPublishMessage>) return;
      final pubMess = recMess.payload;
      final pt =
          MqttPublishPayload.bytesToStringAsString(pubMess.payload.message);
      mensagem = pt;
      setState(() {});
      print(
          'EXAMPLE::Change notification:: topic is <${recMess.topic}>, payload is <-- $pt -->');
      print('');
    });

    /// If needed you can listen for published messages that have completed the publishing
    /// handshake which is Qos dependant. Any message received on this stream has completed its
    /// publishing handshake with the broker.
    client.published!.listen((MqttPublishMessage message) {
      print(
          'EXAMPLE::Published notification:: topic is ${message.variableHeader!.topicName}, with Qos ${message.header!.qos}');
      if (message.variableHeader!.topicName == topic3) {
        print('EXAMPLE:: Non subscribed topic received.');
      }
    });

    final builder1 = MqttClientPayloadBuilder();
    builder1.addString(LigaLED);
    print('EXAMPLE:: <<<< PUBLISH 1 >>>>');
    client.publishMessage(topic1, MqttQos.atLeastOnce, builder1.payload!);

    final builder2 = MqttClientPayloadBuilder();
    builder2.addString(LigaLED);
    print('EXAMPLE:: <<<< PUBLISH 2 >>>>');
    client.publishMessage(topic2, MqttQos.atLeastOnce, builder2.payload!);

    final builder3 = MqttClientPayloadBuilder();
    builder3.addString(LigaLED);
    print('EXAMPLE:: <<<< PUBLISH 3 - NO SUBSCRIPTION >>>>');
    client.publishMessage(topic3, MqttQos.atLeastOnce, builder3.payload!);

    print('EXAMPLE::Sleeping....');
    await MqttUtilities.asyncSleep(60);

    print('EXAMPLE::Unsubscribing');
    client.unsubscribe(topic1);
    client.unsubscribe(topic2);

    await MqttUtilities.asyncSleep(10);
    print('EXAMPLE::Disconnecting');
    client.disconnect();
    return 0;
  }

  /// The subscribed callback
  void onSubscribed(String topic) {
    print('EXAMPLE::Subscription confirmed for topic $topic');
  }

  /// The unsolicited disconnect callback
  void onDisconnected() {
    print('EXAMPLE::OnDisconnected client callback - Client disconnection');
  }
}
