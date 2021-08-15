# flutter_desktop_table_view

A desktop table widget for flutter inspired by QT's QTableView.

## Basic Info

This widget is inspired by QT's QTableView.  The goal is to replicate most of its features.

This widget is intended for the desktop platform, but it can be used on any platform... although
performance will not be ideal.

What is currently implemented:
Lazy load data, sticky headers, scroll bars, scroll with mouse wheel and also middle click + drag,
resizable columns and rows, select cells/rows/columns, edit data, up/down/left/right arrows move
selected cell, and perhaps some other minor things.

Some things not currently implemented:
copy/paste, complex multiple cell selections, cell spans, custom widgets for editing data, and
many other things.

Source code really needs some work.  But at least it's working.

## Installing:

Add the following to your `pubspec.yaml` file:

    dependencies:
      flutter_desktop_table_view: ^0.0.1

## How to use

```dart
import 'package:flutter/material.dart';

import 'package:flutter_desktop_table_view/flutter_desktop_table_view.dart' show TableView, Index;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TableView Example',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('TableView Example'),
        ),
        body: makeTable(),
      ),
    );
  }
}

Widget makeTable() {
  final data = Map<Index, String>();

  return TableView(
    columnCount: () => 10,
    rowCount: () => 100,
    data: (index) {
      if (data.containsKey(index)) return data[index]!;
      return '${index.row}, ${index.column}';
    },
    setData: (index, value) {
      data[index] = value;
    },
    dataWidget: (index, selected) {
      // currently this is not used, so just returning empty container
      return Container();
    },
    horizontalHeaderData: (column) {
      return 'Col $column';
    },
    verticalHeaderData: (row) {
      return 'Row $row';
    },
  );
}

```
