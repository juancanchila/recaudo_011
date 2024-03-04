import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  ValueNotifier<dynamic> result = ValueNotifier(null);
  int decimalValue = 0;
  bool getBalanceResult = false;
  List<dynamic> transactions = [];
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _tagRead();
  }

@override
Widget build(BuildContext context) {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        title: Text(
          'Consulta de Saldo',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Container(
          color: Colors.orange,
          padding: EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 3,
                        blurRadius: 7,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(10),
                  child: SingleChildScrollView(
                    child: ValueListenableBuilder<dynamic>(
                      valueListenable: result,
                      builder: (context, value, _) {
                        if (transactions.isEmpty) {
                          return Center(child: Text('${value ?? ''}'));
                        } else {
                          return DataTable(
                            columns: [
                              DataColumn(label: Text('Nombre TRX')),
                              DataColumn(label: Text('Fecha TRX')),
                              DataColumn(label: Text('Lugar')),
                              DataColumn(label: Text('Monto Abono')),
                              DataColumn(label: Text('Monto Descuento')),
                            ],
                            rows: transactions.map((transaction) {
                              return DataRow(cells: [
                                DataCell(Text('${transaction['nombreTRX'] ?? ''}')),
                                DataCell(Text('${transaction['fechaTRX'] ?? ''}')),
                                DataCell(Text('${transaction['lugar'] ?? ''}')),
                                DataCell(Text('${transaction['montoAbono'] ?? ''}')),
                                DataCell(Text('${transaction['montoDescuento'] ?? ''}')),
                              ]);
                            }).toList(),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              Visibility(
                visible: getBalanceResult,
                child: ElevatedButton(
                  onPressed: () {
                    _getTransactionDetails(decimalValue).then((value) {
                      setState(() {
                        transactions = value;
                      });
                    });
                  },
                  child: Text('Detalle de Transacciones'),
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  _clearAll();
                },
                child: Text('Clear All'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}


  void _tagRead() async {
    FlutterNfcKit.poll().then((NFCTag tag) async {
      try {
        var tagDescription = tag.id.toString();
        String lastTwoCharacters = tagDescription.substring(tagDescription.length - 2);
        String nextTwoCharacters = tagDescription.substring(tagDescription.length - 4, tagDescription.length - 2);
        String nextTwoCharacters2 = tagDescription.substring(tagDescription.length - 6, tagDescription.length - 4);
        String firstTwoCharacters = tagDescription.substring(0, tagDescription.length - 6);
        String hexString = lastTwoCharacters + nextTwoCharacters + nextTwoCharacters2 + firstTwoCharacters;

        decimalValue = int.parse(hexString, radix: 16);
        var hexValue = tag.id.toString();
        await _getBalance(decimalValue,hexValue);

      } catch (error) {
        print("Error reading NFC tag: $error");
      }
    }).catchError((error) {
      print("Error polling NFC tag: $error");
    });
  }

  Future<void> _getBalance(int decimalValue, String hexValue) async {
    var apiUrl = 'http://recaudo.sondapay.com/recaudowsrest/producto/consultaTrx';
    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    var requestBody = jsonEncode({
      "nivelConsulta": 1,
      "tipoConsulta": 2,
      "numExterno": decimalValue.toString(),
    });

    var response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: requestBody,
    );

    if (response.statusCode == 200) {
      getBalanceResult = true;
      var responseData = jsonDecode(response.body);
      var numtarjetaExt = responseData['numtarjetaExt'];
      var saldo = double.parse(responseData['saldo']);
      var estadoCuenta = responseData['estadoCuenta'];

      setState(() {
        result.value = 'Número de tarjeta: $numtarjetaExt\nSaldo: \$${saldo.toStringAsFixed(2)}\nEstado de tarjeta: $estadoCuenta\nHex Value: $hexValue';
      });
    } else {
      setState(() {
        result.value =' Value: $hexValue';
      });
    }
  }

  Future<List<dynamic>> _getTransactionDetails(int decimalValue) async {
    var apiUrl = 'http://recaudo.sondapay.com/recaudowsrest/producto/consultaTrx';
    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    var requestBody = jsonEncode({
      "nivelConsulta": 2,
      "tipoConsulta": 2,
      "fechaDesde": "2023-12-08",
      "fechaHasta": todayDate,
      "numExterno": decimalValue.toString(),
    });

    var response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: requestBody,
    );

    if (response.statusCode == 200) {
      var responseData = jsonDecode(response.body);
      var listaTransacciones = responseData['listaTransacciones'] as List;
      return listaTransacciones;
    } else {
      print('Failed to fetch transaction details. Status code: ${response.statusCode}');
      return [];
    }
  }

void _clearAll() {
  setState(() {
    result.value = null;
    getBalanceResult = false;
    transactions.clear();
  });
  _tagRead(); // Call _tagRead to reset and start reading NFC tags again
}

}
