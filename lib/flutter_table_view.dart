import 'dart:async' show Timer;
import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart' show Tuple2;

int binarySearch(List<double> arr, double userValue, int min, int max) {
  if (max >= 0 && min >= 0 && max < arr.length && max >= min) {
    int mid = ((max + min) / 2).floor();
    if (min == 0 && userValue <= arr[min]) return 0;
    if (userValue == arr[min]) return min;
    if (userValue == arr[max]) return max;
    if (userValue < arr[mid] && userValue > arr[mid - 1]) {
      return mid - 1;
    }
    else if (userValue > arr[mid]) {
      return binarySearch(arr, userValue, mid + 1, max);
    }
    else {
      return binarySearch(arr, userValue, min, mid - 1);
    }
  }
  if (min >= arr.length || max >= arr.length) return arr.length - 1;
  if (min < 0 || max < 0) return 0;
  if (min < 0 || arr[min] >= userValue) return min;
  if (max >= arr.length || userValue >= arr[max]) return max;
  // should never get here
  print(
      'min, max, $userValue, $min, $max, ${arr.length}, -1, ${arr[min]}, ${arr[max]}');
  return -1;
}

class Index extends Tuple2<int, int> {
  Index(int row, int column) : super(row, column);

  int get row {
    return item1;
  }

  int get column {
    return item2;
  }
}


class TableSelection {
  Set<Index> cellSelection = {};
  Set<int> rowSelection = {};
  Set<int> columnSelection = {};
  void Function()? selectionChanged;
  int maxRows;
  int maxColumns;
  List<double> rowOffsets;
  List<double> columnOffsets;
  Index indexWithFocus = Index(-1, -1);
  int focusCount = 0;
  int _focusTimeStamp = 0;
  FocusNode? focusNode;
  GrowingTextField? textField;
  String? textFieldText;

  TableSelection({
    required this.maxRows,
    required this.maxColumns,
    required this.rowOffsets,
    required this.columnOffsets,
  });

  void clear() {
    cellSelection.clear();
    rowSelection.clear();
    columnSelection.clear();
    // indexWithFocus = Index(-1, -1);
    // focusCount = 0;
    // _focusTimeStamp = 0;
  }

  void addCellSelection(Index index) {
    cellSelection.add(index);
    rowSelection.add(index.row);
    columnSelection.add(index.column);
  }

  void addRowSelection(int row) {
    rowSelection.add(row);
    for (int j = 0; j < maxColumns; j++) {
      cellSelection.add(Index(row, j));
      columnSelection.add(j);
    }
  }

  void addColumnSelection(int col) {
    columnSelection.add(col);
    for (int i = 0; i < maxRows; i++) {
      cellSelection.add(Index(i, col));
      rowSelection.add(i);
    }
  }

  void setColumnSelection(Offset pos1, Offset pos2) {
    final x1 = min(pos1.dx, pos2.dx);
    final x2 = max(pos1.dx, pos2.dx);

    final column1 =
    binarySearch(columnOffsets, x1, 0, columnOffsets.length - 1);
    final column2 =
    binarySearch(columnOffsets, x2, 0, columnOffsets.length - 1);

    clear();
    indexWithFocus = Index(-1, -1);

    for (int j = column1; j <= column2; j++) {
      addColumnSelection(j);
    }
  }

  void setRowSelection(Offset pos1, Offset pos2) {
    final y1 = min(pos1.dy, pos2.dy);
    final y2 = max(pos1.dy, pos2.dy);

    final row1 = binarySearch(rowOffsets, y1, 0, rowOffsets.length - 1);
    final row2 = binarySearch(rowOffsets, y2, 0, rowOffsets.length - 1);

    clear();
    indexWithFocus = Index(-1, -1);

    for (int i = row1; i <= row2; i++) {
      addRowSelection(i);
    }
  }

  void setCellSelection(Offset pos1, Offset pos2) {
    final x1 = min(pos1.dx, pos2.dx);
    final x2 = max(pos1.dx, pos2.dx);

    final column1 =
    binarySearch(columnOffsets, x1, 0, columnOffsets.length - 1);
    final column2 =
    binarySearch(columnOffsets, x2, 0, columnOffsets.length - 1);

    final y1 = min(pos1.dy, pos2.dy);
    final y2 = max(pos1.dy, pos2.dy);

    final row1 = binarySearch(rowOffsets, y1, 0, rowOffsets.length - 1);
    final row2 = binarySearch(rowOffsets, y2, 0, rowOffsets.length - 1);

    clear();

    for (int i = row1; i <= row2; i++) {
      for (int j = column1; j <= column2; j++) {
        addCellSelection(Index(i, j));
      }
    }
  }

  Index getIndexFromPosition(Offset pos) {
    late int i;
    late int j;

    if (pos.dx <= columnOffsets[0]) {
      j = 0;
    } else if (pos.dx >= columnOffsets.last) {
      j = columnOffsets.length - 1;
    } else {
      j = binarySearch(columnOffsets, pos.dx, 0, columnOffsets.length - 1);
    }

    if (pos.dy <= rowOffsets[0]) {
      i = 0;
    } else if (pos.dy >= rowOffsets.last) {
      i = rowOffsets.length - 1;
    } else {
      i = binarySearch(rowOffsets, pos.dy, 0, rowOffsets.length - 1);
    }

    return Index(i, j);
  }

  bool isBeingEdited(Index index) {
    if (indexWithFocus == Index(-1, -1)) return false;
    return indexWithFocus == index && focusCount > 1;
  }

  bool hasFocus(Index index) {
    return indexWithFocus == index;
  }

  void setIndexWithFocus(Index index) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    if (index != indexWithFocus)
      focusCount = 0;
    else if (_focusTimeStamp == 0) {
      focusCount = 0;
    } else if (ts - _focusTimeStamp > 500) {
      focusCount = 0;
    }
    _focusTimeStamp = ts;
    indexWithFocus = index;
    focusCount += 1;
  }

  void focusUp() {
    // print(indexWithFocus);
    if (indexWithFocus == Index(-1, -1)) return;
    if (indexWithFocus.row != 0)
      indexWithFocus = Index(indexWithFocus.row - 1, indexWithFocus.column);
    cellSelection.clear();
    cellSelection.add(indexWithFocus);
    rowSelection.clear();
    rowSelection.add(indexWithFocus.row);
    columnSelection.clear();
    columnSelection.add(indexWithFocus.column);
    selectionChanged?.call();
  }

  void focusDown() {
    if (indexWithFocus == Index(-1, -1)) return;
    if (indexWithFocus.row < rowOffsets.length - 2)
      indexWithFocus = Index(indexWithFocus.row + 1, indexWithFocus.column);
    cellSelection.clear();
    cellSelection.add(indexWithFocus);
    rowSelection.clear();
    rowSelection.add(indexWithFocus.row);
    columnSelection.clear();
    columnSelection.add(indexWithFocus.column);
    selectionChanged?.call();
  }

  void focusLeft() {
    if (indexWithFocus == Index(-1, -1)) return;
    if (indexWithFocus.column != 0)
      indexWithFocus = Index(indexWithFocus.row, indexWithFocus.column - 1);
    cellSelection.clear();
    cellSelection.add(indexWithFocus);
    rowSelection.clear();
    rowSelection.add(indexWithFocus.row);
    columnSelection.clear();
    columnSelection.add(indexWithFocus.column);
    selectionChanged?.call();
  }

  void focusRight() {
    if (indexWithFocus == Index(-1, -1)) return;
    if (indexWithFocus.column < columnOffsets.length - 2)
      indexWithFocus = Index(indexWithFocus.row, indexWithFocus.column + 1);
    cellSelection.clear();
    cellSelection.add(indexWithFocus);
    rowSelection.clear();
    rowSelection.add(indexWithFocus.row);
    columnSelection.clear();
    columnSelection.add(indexWithFocus.column);
    selectionChanged?.call();
  }
}

class CellData {
  double width = 0;
  double height = 0;
  TextStyle textStyleDefault = TextStyle(color: Colors.black, fontSize: 14);
  TextStyle textStyleHovered = TextStyle();
  TextStyle textStyleSelected = TextStyle(color: Colors.white, fontSize: 14);
  TextStyle textStyleFocus = TextStyle(color: Colors.black, fontSize: 14);
  BoxDecoration boxDecorationDefault = BoxDecoration(
    color: Colors.white,
    border: Border(
      right: BorderSide(color: Colors.grey.shade300),
      bottom: BorderSide(color: Colors.grey.shade300),
    ),
  );
  BoxDecoration boxDecorationHovered = BoxDecoration(
    color: Colors.lightBlue,
    border: Border(
      right: BorderSide(color: Colors.grey.shade300),
      bottom: BorderSide(color: Colors.grey.shade300),
    ),
  );
  BoxDecoration boxDecorationSelected = BoxDecoration(
    color: Colors.blue,
    border: Border(
      right: BorderSide(color: Colors.grey.shade300),
      bottom: BorderSide(color: Colors.grey.shade300),
    ),
  );
  BoxDecoration boxDecorationFocus = BoxDecoration(
    color: Colors.white,
    border: Border.all(
      color: Colors.blue,
    ),
  );

  CellData({this.width = 0, this.height = 0});

  CellData.header({this.width = 0, this.height = 0}) {
    boxDecorationDefault = boxDecorationDefault.copyWith(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.grey.shade200,
          ],
        ));
    boxDecorationHovered = boxDecorationHovered.copyWith(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.grey.shade200,
          ],
        ));
    boxDecorationSelected = boxDecorationSelected.copyWith(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.grey.shade200,
          ],
        ));
    textStyleSelected = textStyleDefault.copyWith(
      fontWeight: FontWeight.bold,
    );
  }

  // gradient: LinearGradient(
  // begin: Alignment.topRight,
  // end: Alignment.bottomLeft,
  // colors: [
  // Colors.blue,
  // Colors.red,
  // ],
  // )

  TextStyle textStyle(bool focus, bool selected, bool hovered) {
    if (focus)
      return textStyleFocus;
    else if (selected)
      return textStyleSelected;
    else if (hovered) return textStyleHovered;
    return textStyleDefault;
  }

  BoxDecoration boxDecoration(bool focus, bool selected, bool hovered) {
    if (focus)
      return boxDecorationFocus;
    else if (selected)
      return boxDecorationSelected;
    else if (hovered) return boxDecorationHovered;
    return boxDecorationDefault;
  }

  CellData copy() {
    final cpy = CellData();
    cpy.width = width;
    cpy.height = height;
    cpy.textStyleDefault = textStyleDefault;
    cpy.textStyleHovered = textStyleHovered;
    cpy.textStyleSelected = textStyleSelected;
    cpy.textStyleFocus = textStyleFocus;
    cpy.boxDecorationDefault = boxDecorationDefault;
    cpy.boxDecorationHovered = boxDecorationHovered;
    cpy.boxDecorationSelected = boxDecorationSelected;
    cpy.boxDecorationFocus = boxDecorationFocus;
    return cpy;
  }
}

class TableView extends StatefulWidget {
  final String Function(int) verticalHeaderData;
  final String Function(int) horizontalHeaderData;
  final Widget Function(Index index, bool selected) dataWidget;
  final String Function(Index) data;
  final void Function(Index, String) setData;
  late CellData Function(Index index) cellData;
  late CellData Function(int) horizontalHeaderCellData;
  late CellData Function(int) verticalHeaderCellData;
  final int Function() rowCount;
  final int Function() columnCount;
  final defaultCellData = CellData();
  final defaultHorizontalHeaderCellData =
  CellData.header(width: 60, height: 30);
  final defaultVerticalHeaderCellData = CellData.header(width: 60, height: 20);
  final Map<int, CellData> _horizontalHeaderCellData = {};
  final Map<int, CellData> _verticalHeaderCellData = {};
  final List<double> rowPos = [];
  final List<double> columnPos = [];
  double gridHeight = 0;
  double gridWidth = 0;
  bool autoFitHeaders = true;
  _TableViewState? state;
  bool _updatingHeaderSizes = false;

  TableView({
    Key? key,
    required this.data,
    required this.dataWidget,
    required this.horizontalHeaderData,
    required this.verticalHeaderData,
    required this.rowCount,
    required this.columnCount,
    required this.setData,
    CellData Function(Index)? cellData,
    CellData Function(int)? horizontalHeaderCellData,
    CellData Function(int)? verticalHeaderCellData,
    bool this.autoFitHeaders = true,
  }) : super(key: key) {
    this.cellData = cellData != null ? cellData : (index) => defaultCellData;
    this.horizontalHeaderCellData = horizontalHeaderCellData != null
        ? horizontalHeaderCellData
        : (index) {
      if (!_horizontalHeaderCellData.containsKey(index)) {
        _horizontalHeaderCellData[index] =
            defaultHorizontalHeaderCellData.copy();
      }
      return _horizontalHeaderCellData[index]!;
    };
    this.verticalHeaderCellData = verticalHeaderCellData != null
        ? verticalHeaderCellData
        : (index) {
      if (!_verticalHeaderCellData.containsKey(index)) {
        _verticalHeaderCellData[index] =
            defaultVerticalHeaderCellData.copy();
      }
      return _verticalHeaderCellData[index]!;
    };

    if (autoFitHeaders) fitHeaders();

    // print('$gridWidth, $gridHeight');
    // print(rowPos);
    // print(columnPos);
  }

  void fitColumnHeader(int col) {
    final hcd = horizontalHeaderCellData(col);
    var txt = horizontalHeaderData(col);
    var size = _textSize(txt, hcd.textStyleDefault);
    hcd.width = size.width + 10;

    for (int i = 0; i < rowCount(); i++) {
      final index = Index(i, col);
      final cd = cellData(index);
      txt = data(index);
      size = _textSize(txt, cd.textStyleDefault);
      hcd.width = max(hcd.width, size.width + 10);
    }
  }

  void fitRowHeader(int row) {
    final hcd = verticalHeaderCellData(row);
    var txt = verticalHeaderData(row);
    var size = _textSize(txt, hcd.textStyleDefault);
    hcd.height = size.height + 2;

    for (int j = 0; j < columnCount(); j++) {
      final index = Index(row, j);
      final cd = cellData(index);
      txt = data(index);
      size = _textSize(txt, cd.textStyleDefault);
      hcd.height = max(hcd.height, size.height + 2);
    }
  }

  void fitHeaders() {
    // horizontal
    // gridWidth = 0;
    for (int i = 0; i < columnCount(); i++) {
      final cd = horizontalHeaderCellData(i);
      final txt = horizontalHeaderData(i);
      final size = _textSize(txt, cd.textStyleDefault);
      cd.width = max(cd.width, size.width + 10);
      cd.height = max(cd.height, size.height + 2);
      // gridWidth += cd.width;
    }

    // vertical
    // gridHeight = 0;
    for (int i = 0; i < rowCount(); i++) {
      final cd = verticalHeaderCellData(i);
      final txt = verticalHeaderData(i);
      final size = _textSize(txt, cd.textStyleDefault);
      cd.width = max(cd.width, size.width);
      cd.height = max(cd.height, size.height + 2);
      // gridHeight += cd.height;
    }

    // updateHeaderPositions();

    void _sizeForCells() {
      for (int i = 0; i < rowCount(); i += 10) {
        final vcd = verticalHeaderCellData(i);
        for (int j = 0; j < columnCount(); j++) {
          final index = Index(i, j);
          final cd = cellData(index);
          final txt = data(index);
          final size = _textSize(txt, cd.textStyleDefault);
          final hcd = horizontalHeaderCellData(j);
          hcd.width = max(hcd.width, size.width + 10);
          vcd.height = max(vcd.height, size.height + 2);
        }
      }

      updateHeaderPositions();
      state?.update();
    }

    // print(1);
    _sizeForCells();
    // print(2);
  }

  void updateHeaderPositions() {
    rowPos.clear();
    double pos = 0;
    for (int i = 0; i < rowCount(); i++) {
      rowPos.add(pos);
      pos += verticalHeaderCellData(i).height;
    }
    rowPos.add(pos);
    gridHeight = rowPos.last;

    columnPos.clear();
    pos = 0;
    for (int i = 0; i < columnCount(); i++) {
      columnPos.add(pos);
      pos += horizontalHeaderCellData(i).width;
    }
    columnPos.add(pos);
    gridWidth = columnPos.last;
    // print(columnPos);
    // print('!!!!!!!!!!!!!!!!!! $gridWidth');
  }

  Index getIndexFromPosition(Offset pos) {
    late int i;
    late int j;

    if (pos.dx <= columnPos[0]) {
      j = 0;
    } else if (pos.dx >= columnPos.last) {
      j = columnPos.length - 1;
    } else {
      j = binarySearch(columnPos, pos.dx, 0, columnPos.length - 1);
    }

    if (pos.dy <= rowPos[0]) {
      i = 0;
    } else if (pos.dy >= rowPos.last) {
      i = rowPos.length - 1;
    } else {
      i = binarySearch(rowPos, pos.dy, 0, rowPos.length - 1);
    }

    return Index(i, j);
  }

  @override
  _TableViewState createState() {
    if (state == null) {
      state = _TableViewState();
    }
    return state!;
  }
}

class _TableViewState extends State<TableView> {
  double verticalScrollPosition = 0;
  double horizontalScrollPosition = 0;
  final verticalScrollBarKey = ScrollBar.makeGlobalKey();
  final horizontalScrollBarKey = ScrollBar.makeGlobalKey();
  final tableGridKey = TableGrid.makeGlobalKey();
  final verticalHeaderKey = TableHeader.makeGlobalKey();
  final horizontalHeaderKey = TableHeader.makeGlobalKey();
  TableSelection? selection;
  final focusNode = FocusNode(debugLabel: 'TableView');

  // @override
  // void initState() {
  //   super.initState();
  // }

  void update() {
    if (!mounted) return;
    // if (widget.autoFitHeaders) widget.fitHeaders();
    setState(() {});
  }

  void verticalScrollUpdate(double position, {bool updateGrid = true}) {
    verticalScrollPosition = position;
    // verticalHeaderKey.currentState?.update();
    // verticalScrollBarKey.currentState?.update();
    // verticalHeaderKey.currentState?
    if (updateGrid) update();
  }

  void horizontalScrollUpdate(double position, {bool updateGrid = true}) {
    horizontalScrollPosition = position;
    // horizontalHeaderKey.currentState?.update();
    // horizontalScrollBarKey.currentState?.update();
    if (updateGrid) update();
  }

  @override
  Widget build(BuildContext context) {
    // focusNode.requestFocus();

    if (selection == null) {
      selection = TableSelection(
        maxRows: widget.rowCount(),
        maxColumns: widget.columnCount(),
        rowOffsets: widget.rowPos,
        columnOffsets: widget.columnPos,
      );
    } else {
      selection?.maxRows = widget.rowCount();
      selection?.maxColumns = widget.columnCount();
      selection?.rowOffsets = widget.rowPos;
      selection?.columnOffsets = widget.columnPos;
    }

    // focusNode.onKey = _onKey;

    return Focus(
      focusNode: focusNode,
      autofocus: true,
      onKey: (node, event) {
        // print(node);
        // print(event);
        if (selection == null) return KeyEventResult.ignored;
        if (selection!.focusNode != null) {
          if (selection!.focusNode!.hasPrimaryFocus)
            return KeyEventResult.ignored;
        }

        if (event is RawKeyDownEvent) {
          final keyLabel = event.logicalKey.keyLabel;
          if (keyLabel == 'Arrow Up') {
            // print('up');
            selection!.focusUp();
            return KeyEventResult.handled;
          } else if (keyLabel == 'Arrow Down') {
            selection!.focusDown();
            return KeyEventResult.handled;
          } else if (keyLabel == 'Arrow Left') {
            // print(focusNode.hasPrimaryFocus);
            selection!.focusLeft();
            return KeyEventResult.handled;
          } else if (keyLabel == 'Arrow Right') {
            selection!.focusRight();
            return KeyEventResult.handled;
          } else if (keyLabel == 'Escape') {
            return KeyEventResult.handled;
          } else if (keyLabel == 'Enter') {
            return KeyEventResult.ignored;
          } else {
            if (selection!.indexWithFocus != Index(-1, -1) &&
                selection!.focusNode == null) {
              selection!.focusCount = 2;
              selection!.textFieldText = event.character.toString();
              // print('update 2');
              update();
              return KeyEventResult.handled;
            }
            // print(selection!.focusNode);
            // focusNode.unfocus();

            // selection!.focusNode?.requestFocus();
            // print('set text');
            if (selection!.focusNode != null) {
              if (selection!.focusNode!.hasPrimaryFocus) {
                // print('return 1');
                return KeyEventResult.ignored;
              }
            }
            // print('set text');
            // print(selection!.textField);
            // selection!.textField?.setText(event.character.toString());
            // selection!.focusNode?.onKey?.call(selection!.focusNode!, event);
            return KeyEventResult.handled;
            // selection!.focusNode?.onKey?.call(selection!.focusNode!, event);
          }
        }

        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(builder: (context, box) {
        final totalRows = widget.rowCount().toDouble();
        final totalCols = widget.columnCount().toDouble();

        final verticalHeaderWidth = widget.defaultVerticalHeaderCellData.width;
        final horizontalHeaderHeight =
            widget.defaultHorizontalHeaderCellData.height;
        final colWidth = 60.0;
        final rowHeight = 20.0;

        final checkCols =
            box.maxWidth - verticalHeaderWidth >= widget.gridWidth;
        final checkRows =
            box.maxHeight - horizontalHeaderHeight >= widget.gridHeight;

        final verticalScrollWidth = checkRows ? 0.0 : 20.0;
        final horizontalScrollHeight = checkCols ? 0.0 : 20.0;
        final tableGridWidth =
            box.maxWidth - verticalHeaderWidth - verticalScrollWidth;
        final tableGridHeight =
            box.maxHeight - horizontalScrollHeight - horizontalHeaderHeight;

        // print('index1');
        final x1 = horizontalScrollPosition * widget.gridWidth;
        final y1 = verticalScrollPosition * widget.gridHeight;
        final index1 = widget.getIndexFromPosition(Offset(x1, y1));

        // print('index2');
        final x2 = min(x1 + tableGridWidth, widget.gridWidth);
        final y2 = min(y1 + tableGridHeight, widget.gridHeight);
        final index2 = widget.getIndexFromPosition(Offset(x2, y2));

        verticalScrollPosition = max(
            0,
            min(verticalScrollPosition,
                1 - tableGridHeight / (widget.gridHeight)));
        horizontalScrollPosition = max(
            0,
            min(horizontalScrollPosition,
                1 - tableGridWidth / (widget.gridWidth)));

        if (checkRows) verticalScrollPosition = 0;
        if (checkCols) horizontalScrollPosition = 0;

        final firstRow = index1.row.toDouble();
        final lastRow = min(totalRows, index2.row.toDouble() + 1.0);

        final firstCol = index1.column.toDouble();
        final lastCol = min(totalCols, index2.column.toDouble() + 1.0);

        void _verticalScroll(double delta) {
          verticalScrollBarKey.currentState?.updateScroll(delta);
        }

        void _horizontalScroll(double delta) {
          horizontalScrollBarKey.currentState?.updateScroll(delta);
        }

        selection!.selectionChanged = () {
          // print('update 3');
          update();
          // tableGridKey.currentState?.update();
          // verticalHeaderKey.currentState?.update();
          // horizontalHeaderKey.currentState?.update();
        };

        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              final dy = event.scrollDelta.dy * 3;
              final dx = event.scrollDelta.dx;

              bool gridUpdated = false;

              if (dy != 0) {
                var delta = dy / rowHeight / totalRows;
                final oldPosition = verticalScrollBarKey.currentState!.position;
                var newPosition = oldPosition + delta;

                if (delta < 0) {
                  newPosition -= 0.4999999 / totalRows;
                } else {
                  newPosition += 0.4999999 / totalRows;
                }

                final newRowPosition = newPosition * totalRows;
                delta =
                    newRowPosition.roundToDouble() / totalRows - oldPosition;
                if (dx == 0) gridUpdated = true;
                verticalScrollBarKey.currentState
                    ?.updateScroll(delta, updateGrid: gridUpdated);
              }

              if (dx != 0) {
                var delta = dx / colWidth / totalCols;
                final oldPosition =
                    horizontalScrollBarKey.currentState!.position;
                var newPosition = oldPosition + delta;

                if (delta < 0) {
                  newPosition -= 0.4999999 / totalCols;
                } else {
                  newPosition += 0.4999999 / totalCols;
                }

                final newRowPosition = newPosition * totalCols;
                delta =
                    newRowPosition.roundToDouble() / totalCols - oldPosition;
                horizontalScrollBarKey.currentState?.updateScroll(delta,
                    updateGrid: gridUpdated ? false : true);
              }
            }
          },
          // onPointerDown: (event) {
          //   if (event is PointerDownEvent) {
          //     print(event.buttons);
          //   }
          // },
          child: Stack(
            children: [
              Positioned(
                  left: 0,
                  top: 0,
                  child: SizedBox(
                    width: box.maxWidth,
                    height: box.maxHeight,
                    child: Container(color: Colors.transparent),
                  )),
              TableGrid(
                globalKey: tableGridKey,
                top: horizontalHeaderHeight,
                left: verticalHeaderWidth,
                bottom: null,
                right: null,
                width: tableGridWidth,
                height: tableGridHeight,
                rowHeight: rowHeight,
                colWidth: colWidth,
                firstRow: firstRow,
                lastRow: lastRow,
                firstCol: firstCol,
                lastCol: lastCol,
                data: widget.data,
                onVerticalScroll: _verticalScroll,
                onHorizontalScroll: _horizontalScroll,
                cellData: widget.cellData,
                horizontalHeaderCellData: widget.horizontalHeaderCellData,
                verticalHeaderCellData: widget.verticalHeaderCellData,
                xOffset: horizontalScrollPosition * widget.gridWidth,
                yOffset: verticalScrollPosition * widget.gridHeight,
                rowPos: widget.rowPos,
                columnPos: widget.columnPos,
                getIndexFromPosition: widget.getIndexFromPosition,
                selection: selection!,
                setData: widget.setData,
                tableFocusNode: focusNode,
              ),
              TableHeader(
                globalKey: verticalHeaderKey,
                top: horizontalHeaderHeight,
                left: 0,
                width: 90,
                bottom: null,
                right: null,
                height: tableGridHeight,
                firstPos: firstRow,
                lastPos: lastRow,
                cellHeight: 20,
                cellWidth: 90,
                orientation: TableHeaderOrientation.vertical,
                data: widget.verticalHeaderData,
                cellData: widget.verticalHeaderCellData,
                offset: verticalScrollPosition * widget.gridHeight,
                pos: widget.rowPos,
                selection: selection!.rowSelection,
                tableSelection: selection!,
                headerSizeChanged: widget.updateHeaderPositions,
                fitHeader: widget.fitRowHeader,
              ),
              TableHeader(
                globalKey: horizontalHeaderKey,
                top: 0,
                left: verticalHeaderWidth,
                width: tableGridWidth,
                bottom: null,
                right: null,
                height: 30,
                firstPos: firstCol,
                lastPos: lastCol,
                cellHeight: 30,
                cellWidth: 60,
                orientation: TableHeaderOrientation.horizontal,
                data: widget.horizontalHeaderData,
                cellData: widget.horizontalHeaderCellData,
                offset: horizontalScrollPosition * widget.gridWidth,
                pos: widget.columnPos,
                selection: selection!.columnSelection,
                tableSelection: selection!,
                headerSizeChanged: widget.updateHeaderPositions,
                fitHeader: widget.fitColumnHeader,
              ),
              // rowCount >= totalRows
              tableGridHeight >= widget.gridHeight
                  ? Container()
                  : ScrollBar(
                globalKey: verticalScrollBarKey,
                onUpdate: verticalScrollUpdate,
                // handleSize: rowCount / totalRows,
                handleSize: tableGridHeight / widget.gridHeight,
                orientation: ScrollBarOrientation.vertical,
                top: 0,
                right: 0,
                bottom: null,
                left: null,
                width: min(20, box.maxWidth),
                height: box.maxHeight - horizontalScrollHeight,
              ),
              // colCount >= totalCols
              tableGridWidth >= widget.gridWidth
                  ? Container()
                  : ScrollBar(
                globalKey: horizontalScrollBarKey,
                onUpdate: horizontalScrollUpdate,
                // handleSize: colCount / totalCols,
                handleSize: tableGridWidth / widget.gridWidth,
                orientation: ScrollBarOrientation.horizontal,
                bottom: 0,
                left: 0,
                top: null,
                right: null,
                width: box.maxWidth - verticalScrollWidth,
                height: min(20, box.maxHeight),
              ),
            ],
          ),
        );
      }),
    );
  }
}

enum TableHeaderOrientation { horizontal, vertical }

class TableHeader extends StatefulWidget {
  static final Orientation = TableHeaderOrientation;

  final GlobalKey<_TableHeaderState> globalKey;
  final double? top;
  final double? left;
  final double? bottom;
  final double? right;
  final double width;
  final double height;
  final double firstPos;
  final double lastPos;
  final double cellHeight;
  final double cellWidth;
  final TableHeaderOrientation orientation;
  final String Function(int) data;
  final CellData Function(int) cellData;
  final double offset;
  final List<double> pos;
  final Set<int> selection;
  final TableSelection tableSelection;
  final void Function() headerSizeChanged;
  final void Function(int) fitHeader;

  static GlobalKey<_TableHeaderState> makeGlobalKey() {
    return GlobalKey<_TableHeaderState>();
  }

  TableHeader({
    required this.globalKey,
    required this.top,
    required this.left,
    required this.bottom,
    required this.right,
    required this.width,
    required this.height,
    required this.firstPos,
    required this.lastPos,
    required this.orientation,
    required this.cellHeight,
    required this.cellWidth,
    required this.data,
    required this.cellData,
    required this.offset,
    required this.pos,
    required this.selection,
    required this.tableSelection,
    required this.headerSizeChanged,
    required this.fitHeader,
  }) : super(key: globalKey);

  @override
  _TableHeaderState createState() => _TableHeaderState();
}

class _TableHeaderState extends State<TableHeader> {
  bool selectionInProcess = false;
  bool selectionChanged = false;
  Offset? firstSelectionPos;
  Offset? lastSelectionPos;
  bool resizeOn = false;
  int resizeIndex = 0;
  double originalHeaderSize = 0;
  bool rebuilding = false;
  int taps = 0;
  int firstTapTime = 0;
  bool resizeHovered = false;
  Offset? firstTapPos;
  Offset? lastTapPos;

  void update() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final isVertical = widget.orientation == TableHeaderOrientation.vertical;

    Widget makeCell(int i) {
      final cd = widget.cellData(i);
      final selected = widget.selection.contains(i);

      // print('$i, ${widget.pos[i] - widget.offset}');

      return Positioned(
        top: isVertical ? widget.pos[i] - widget.offset : 0,
        left: isVertical ? 0 : widget.pos[i] - widget.offset,
        child: SizedBox(
          width: cd.width,
          height: cd.height,
          // child: Container(
          //   margin: const EdgeInsets.all(0),
          //   padding: const EdgeInsets.all(0),
          //   decoration:
          //       BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
          //   child: Text('Index $pos'),
          // ),
          child: Container(
            margin: const EdgeInsets.all(0),
            padding: const EdgeInsets.all(0),
            decoration: cd.boxDecoration(false, selected, false),
            child: Center(
                child: Text(
                  widget.data(i),
                  style: cd.textStyle(false, selected, false),
                )),
          ),
        ),
      );
    }

    // print('${widget.firstPos}, ${widget.lastPos}');

    for (int i = widget.firstPos.toInt(); i < widget.lastPos; i++) {
      children.add(makeCell(i));
    }

    const double handleSize = 3;

    Widget makeResizeWidget(int i) {
      final cd = widget.cellData(i);

      return Positioned(
        top: isVertical ? widget.pos[i] - widget.offset - handleSize : 0,
        left: isVertical ? 0 : widget.pos[i] - widget.offset - handleSize,
        child: SizedBox(
          width: isVertical ? cd.width : 2 * handleSize,
          height: isVertical ? 2 * handleSize : cd.height,
          child: MouseRegion(
            onEnter: (event) {
              resizeHovered = true;
              if (resizeOn || selectionInProcess) return;
              resizeOn = true;
              resizeIndex = i - 1;
              taps = 0;
              final cd = widget.cellData(resizeIndex);
              originalHeaderSize = isVertical ? cd.height : cd.width;
            },
            onExit: (event) {
              resizeHovered = false;
              if (event.buttons != 0) return;
              resizeOn = false;
            },
            cursor: isVertical
                ? SystemMouseCursors.resizeRow
                : SystemMouseCursors.resizeColumn,
            child: Container(
              // color: Colors.blue,
            ),
          ),
        ),
      );
    }

    for (int i = widget.firstPos.toInt(); i <= widget.lastPos; i++) {
      if (i == 0) continue;
      children.add(makeResizeWidget(i));
    }

    void doubleTap() {
      taps = 0;
      if (resizeHovered) {
        widget.fitHeader(resizeIndex);
        widget.headerSizeChanged.call();
        widget.tableSelection.selectionChanged?.call();
        return;
      }

      final index = widget.tableSelection.getIndexFromPosition(lastTapPos!);
      // if (index.row != -1 && index.column != -1) {
      //   print('double tap $index');
      // }
    }

    return Positioned(
      top: widget.top,
      bottom: widget.bottom,
      left: widget.left,
      right: widget.right,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Listener(
          onPointerDown: (event) {
            // print(event);
            if (event is PointerDownEvent) {
              if (event.buttons == 1) {
                if (taps == 0) {
                  firstTapTime = event.timeStamp.inMilliseconds;
                  firstTapPos = event.localPosition;
                  taps += 1;
                } else if (event.timeStamp.inMilliseconds - firstTapTime <=
                    500) {
                  lastTapPos = event.localPosition;
                  final tapDelta = lastTapPos! - firstTapPos!;
                  if (tapDelta.dx.abs() <= 1 && tapDelta.dy.abs() <= 1) {
                    doubleTap();
                    return;
                  }
                }

                selectionInProcess = true;
                selectionChanged = true;

                late Offset offset;
                if (isVertical) {
                  offset = Offset(0.0, widget.offset);
                } else {
                  offset = Offset(widget.offset, 0.0);
                }

                firstSelectionPos = event.localPosition + offset;
                lastSelectionPos = firstSelectionPos;

                if (resizeHovered) return;

                if (isVertical) {
                  widget.tableSelection
                      .setRowSelection(firstSelectionPos!, lastSelectionPos!);
                } else {
                  widget.tableSelection.setColumnSelection(
                      firstSelectionPos!, lastSelectionPos!);
                }

                widget.tableSelection.selectionChanged?.call();
              }
            }
          },
          onPointerUp: (event) {
            if (event is PointerUpEvent) {
              if (event.buttons == 0) {
                selectionInProcess = false;
                resizeOn = false;
              }
            }
          },
          onPointerMove: (event) {
            if (resizeOn) {
              if (rebuilding) return;

              late Offset offset;
              if (isVertical) {
                offset = Offset(0.0, widget.offset);
              } else {
                offset = Offset(widget.offset, 0.0);
              }

              lastSelectionPos = event.localPosition + offset;

              final cd = widget.cellData(resizeIndex);

              if (isVertical) {
                cd.height = max(
                    0.0,
                    originalHeaderSize +
                        lastSelectionPos!.dy -
                        firstSelectionPos!.dy);
              } else {
                cd.width = max(
                    0.0,
                    originalHeaderSize +
                        lastSelectionPos!.dx -
                        firstSelectionPos!.dx);
              }

              rebuilding = true;
              widget.headerSizeChanged.call();
              widget.tableSelection.selectionChanged?.call();
              rebuilding = false;
              taps = 0;
            } else if (selectionInProcess) {
              late Offset offset;
              if (isVertical) {
                offset = Offset(0.0, widget.offset);
              } else {
                offset = Offset(widget.offset, 0.0);
              }

              lastSelectionPos = event.localPosition + offset;

              if (isVertical) {
                widget.tableSelection
                    .setRowSelection(firstSelectionPos!, lastSelectionPos!);
              } else {
                widget.tableSelection
                    .setColumnSelection(firstSelectionPos!, lastSelectionPos!);
              }

              widget.tableSelection.selectionChanged?.call();
              taps = 0;
            }
          },
          child: Stack(
            children: children,
          ),
        ),
      ),
    );
  }
}

class TableGrid extends StatefulWidget {
  final GlobalKey<_TableGridState> globalKey;
  final double? top;
  final double? left;
  final double? bottom;
  final double? right;
  final double width;
  final double height;
  final double rowHeight;
  final double colWidth;
  final double firstRow;
  final double lastRow;
  final double firstCol;
  final double lastCol;
  Widget Function(Index index, bool selected)? dataWidget;
  final String Function(Index) data;
  final void Function(double) onVerticalScroll;
  final void Function(double) onHorizontalScroll;
  final CellData Function(Index) cellData;
  final CellData Function(int) horizontalHeaderCellData;
  final CellData Function(int) verticalHeaderCellData;
  final double xOffset;
  final double yOffset;
  final List<double> rowPos;
  final List<double> columnPos;
  final Index Function(Offset) getIndexFromPosition;
  final TableSelection selection;
  final void Function(Index, String) setData;
  final FocusNode tableFocusNode;

  static GlobalKey<_TableGridState> makeGlobalKey() {
    return GlobalKey<_TableGridState>();
  }

  TableGrid({
    required this.globalKey,
    required this.top,
    required this.left,
    required this.bottom,
    required this.right,
    required this.width,
    required this.height,
    required this.rowHeight,
    required this.colWidth,
    required this.firstRow,
    required this.lastRow,
    required this.firstCol,
    required this.lastCol,
    required this.data,
    required this.onVerticalScroll,
    required this.onHorizontalScroll,
    required this.cellData,
    required this.horizontalHeaderCellData,
    required this.verticalHeaderCellData,
    required this.xOffset,
    required this.yOffset,
    required this.rowPos,
    required this.columnPos,
    required this.getIndexFromPosition,
    required this.selection,
    required this.setData,
    required this.tableFocusNode,
  }) : super(key: globalKey);

  @override
  _TableGridState createState() => _TableGridState();
}

class _TableGridState extends State<TableGrid> {
  bool middleButtonDown = false;
  Offset middleButtonDownPos = Offset(0, 0);
  Timer? scrollTimer;
  Offset? firstSelectionPos;
  Offset? lastSelectionPos;
  bool selectionInProcess = false;
  bool selectionChanged = false;
  int taps = 0;
  Offset? firstTapPos;
  Offset? lastTapPos;
  int firstTapTime = 0;
  int lastTapTime = 0;
  final focusNode = FocusNode(debugLabel: 'TableCell');
  GrowingTextField? textField;

  void update() {
    if (!mounted) return;
    setState(() {});
  }

  List<Widget> _buildChildren() {
    Widget? focusWidget;

    widget.selection.focusNode = null;
    widget.selection.textField = null;

    Widget makeCell(int i, int j) {
      final index = Index(i, j);
      final cd = widget.cellData(index);
      final hcd = widget.horizontalHeaderCellData(index.column);
      final vcd = widget.verticalHeaderCellData(index.row);
      final selected = widget.selection.cellSelection.contains(index);

      final cellBeingEdited = widget.selection.isBeingEdited(index);
      final hasFocus = widget.selection.hasFocus(index) && cellBeingEdited;
      late Widget result;

      if (cellBeingEdited) {

        final left = widget.columnPos[j] - widget.xOffset;

        result = widget.selection.textField = GrowingTextField(
          left: left,
          top: widget.rowPos[i] - widget.yOffset,
          width: hcd.width,
          height: vcd.height,
          text: widget.selection.textFieldText != null
              ? widget.selection.textFieldText!
              : widget.data(index),
          // style: cd.textStyle(selected, false),
          // decoration: cd.boxDecoration(selected, false),
          decoration: cd.boxDecorationFocus,
          style: cd.textStyleFocus,
          focusNode: focusNode,
          maxWidth: widget.width - left,
          index: index,
          autoFocus: cellBeingEdited,
          tableSelection: widget.selection,
          tableFocusNode: widget.tableFocusNode,
          submitData: (index, data, clearFocus) {
            try {
              // print(index);
              // print(data);
              widget.setData(index, data);
            } catch (e) {
              print(e.toString());
            }
            if (clearFocus) {
              focusNode.unfocus();
              widget.tableFocusNode.requestFocus();
              widget.selection.focusCount = 0;
            }
            // if (clearFocus) widget.selection.setIndexWithFocus(Index(-1, -1));
            // print('update 4');
            update();
          },
        );

        widget.selection.textFieldText = null;
        widget.selection.focusNode = focusNode;

      } else {
        // child = Text(widget.data(index), style: cd.textStyle(selected, false));
        result = Positioned(
          top: widget.rowPos[i] - widget.yOffset,
          left: widget.columnPos[j] - widget.xOffset,
          child: SizedBox(
            width: hcd.width,
            height: vcd.height,
            child: Container(
              margin: const EdgeInsets.all(0),
              padding: const EdgeInsets.only(left: 5),
              decoration: cd.boxDecoration(hasFocus, selected, false),
              child: Text(widget.data(index),
                  style: cd.textStyle(hasFocus, selected, false)),
            ),
          ),
        );

        // widget.selection.focusNode = null;

      }

      // final result = Positioned(
      //   top: widget.rowPos[i] - widget.yOffset,
      //   left: widget.columnPos[j] - widget.xOffset,
      //   child: SizedBox(
      //     width: hcd.width * (cellBeingEdited ? 1.5 : 1),
      //     height: vcd.height,
      //     child: Container(
      //       margin: const EdgeInsets.all(0),
      //       padding: const EdgeInsets.only(left: 5),
      //       decoration: cd.boxDecoration(selected, false),
      //       child: child,
      //     ),
      //   ),
      // );

      if (cellBeingEdited) focusWidget = result;
      return result;
    }

    final children = <Widget>[];

    for (int i = widget.firstRow.toInt(); i < widget.lastRow; i++) {
      for (int j = widget.firstCol.toInt(); j < widget.lastCol; j++) {
        final w = makeCell(i, j);
        if (w == focusWidget) continue;
        children.add(w);
      }
    }

    if (focusWidget != null) children.add(focusWidget!);

    return children;
  }

  @override
  Widget build(BuildContext context) {
    final children = _buildChildren();

    void doubleTap() {
      // print('double tap');
      taps = 0;
      final index = widget.selection.getIndexFromPosition(lastSelectionPos!);
      widget.selection.setIndexWithFocus(index);
      widget.selection.selectionChanged?.call();
    }

    return Positioned(
      left: widget.left,
      right: widget.right,
      top: widget.top,
      bottom: widget.bottom,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Listener(
          onPointerDown: (event) {
            // focusNode.requestFocus();

            final selectionPos =
                event.localPosition + Offset(widget.xOffset, widget.yOffset);
            final selectionIndex =
            widget.selection.getIndexFromPosition(selectionPos);

            final textFieldFocusNode = widget.selection.focusNode;
            if (textFieldFocusNode != null &&
                textFieldFocusNode.hasPrimaryFocus &&
                selectionIndex == widget.selection.textField!.index) {
              // print('return');
              // print(selectionIndex);
              // print(widget.selection.textField!.index);
              return;
            }

            widget.tableFocusNode.requestFocus();
            // print('request');
            if (event is PointerDownEvent) {
              if (event.buttons == 4) {
                taps = 0;
                middleButtonDown = true;
                middleButtonDownPos = event.localPosition;
                // print(middleButtonDownPos);
              } else if (event.buttons == 1) {
                taps += 1;
                // print(taps);

                if (taps == 1) {
                  firstTapTime = event.timeStamp.inMilliseconds;
                  firstTapPos = event.localPosition;
                } else if (firstSelectionPos == lastSelectionPos) {
                  lastTapTime = event.timeStamp.inMilliseconds;
                  lastTapPos = event.localPosition;

                  if (lastTapTime - firstTapTime <= 500) {
                    final delta = lastTapPos! - firstTapPos!;
                    if (delta.dx.abs() <= 1 && delta.dy.abs() <= 1) {
                      doubleTap();
                      return;
                    }
                  }

                  taps = 0;
                }

                // taps = 1;

                firstSelectionPos = event.localPosition +
                    Offset(widget.xOffset, widget.yOffset);

                if (firstSelectionPos != lastSelectionPos) {
                  taps = 1;
                  firstTapTime = event.timeStamp.inMilliseconds;
                  firstTapPos = event.localPosition;
                }

                lastSelectionPos = firstSelectionPos;
                selectionInProcess = true;
                selectionChanged = true;
                widget.selection
                    .setCellSelection(firstSelectionPos!, lastSelectionPos!);
                final index =
                widget.selection.getIndexFromPosition(lastSelectionPos!);
                if (widget.selection.isBeingEdited(index)) return;
                widget.selection.setIndexWithFocus(index);
                widget.selection.selectionChanged?.call();
                // update();
              }
            }
          },
          onPointerUp: (event) {
            // print(event);
            if (event is PointerUpEvent) {
              // print(event.buttons);
              if (event.buttons == 0) {
                middleButtonDown = false;
                scrollTimer?.cancel();
                selectionInProcess = false;
                // print('cancel');
              }
            }
          },
          onPointerMove: (event) {
            if (selectionInProcess) {
              taps = 0;
              lastSelectionPos =
                  event.localPosition + Offset(widget.xOffset, widget.yOffset);
              selectionChanged = true;
              widget.selection
                  .setCellSelection(firstSelectionPos!, lastSelectionPos!);
              widget.selection.selectionChanged?.call();

              void _xScroll(double dx) {
                scrollTimer?.cancel();
                scrollTimer =
                    Timer.periodic(Duration(milliseconds: 16), (timer) {
                      widget.onHorizontalScroll.call(dx / widget.width / 50);
                      dx *= 1.1;
                    });
              }

              void _yScroll(double dy) {
                scrollTimer?.cancel();
                scrollTimer =
                    Timer.periodic(Duration(milliseconds: 16), (timer) {
                      widget.onVerticalScroll.call(dy / widget.height / 50);
                      dy *= 1.1;
                      // widget.selection.selectionChanged?.call();
                    });
              }

              final delta = lastSelectionPos! - firstSelectionPos!;

              final xOutOfBounds = event.localPosition.dx > widget.width ||
                  event.localPosition.dx < 0;
              final yOutOfBounds = event.localPosition.dy > widget.height ||
                  event.localPosition.dy < 0;

              final dy = event.localPosition.dy >= 0
                  ? event.localPosition.dy - widget.height
                  : event.localPosition.dy;
              final dx = event.localPosition.dx >= 0
                  ? event.localPosition.dx - widget.width
                  : event.localPosition.dx;

              if (xOutOfBounds && yOutOfBounds) {
                if (delta.dx.abs() > delta.dy.abs()) {
                  _xScroll(dx);
                } else {
                  _yScroll(dy);
                }
              } else if (xOutOfBounds) {
                _xScroll(dx);
              } else if (yOutOfBounds) {
                _yScroll(dy);
              }
            } else if (middleButtonDown) {
              taps = 0;
              final currentPos = event.localPosition;
              final delta = currentPos - middleButtonDownPos;
              if (delta.dx.abs() > delta.dy.abs()) {
                scrollTimer?.cancel();
                scrollTimer =
                    Timer.periodic(Duration(milliseconds: 16), (timer) {
                      widget.onHorizontalScroll.call(delta.dx / widget.width / 10);
                    });

                // widget.onHorizontalScroll.call(delta.dx / widget.width / 10);
              } else {
                scrollTimer?.cancel();
                scrollTimer =
                    Timer.periodic(Duration(milliseconds: 16), (timer) {
                      widget.onVerticalScroll.call(delta.dy / widget.height / 10);
                    });
                // widget.onVerticalScroll.call(delta.dy / widget.height / 10);
              }
            }
          },
          child: Stack(
            children: children,
          ),
        ),
      ),
    );
  }
}

class SizedBoxText extends StatefulWidget {
  final double width;
  final double height;
  final Widget child;
  final bool selected;

  const SizedBoxText(
      {Key? key,
        required this.width,
        required this.height,
        required this.child,
        required this.selected})
      : super(key: key);

  @override
  _SizedBoxTextState createState() => _SizedBoxTextState();
}

class _SizedBoxTextState extends State<SizedBoxText> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: widget.child,
    );
  }
}

enum ScrollBarOrientation {
  vertical,
  horizontal,
}

class ScrollBar extends StatefulWidget {
  final GlobalKey<_ScrollBarState> globalKey;
  final void Function(double, {bool updateGrid}) onUpdate;
  double handleSize;
  final ScrollBarOrientation orientation;
  final double? top;
  final double? left;
  final double? bottom;
  final double? right;
  final double width;
  final double height;

  static makeGlobalKey() {
    return GlobalKey<_ScrollBarState>();
  }

  ScrollBar({
    required this.globalKey,
    required this.onUpdate,
    required this.handleSize,
    required this.orientation,
    required this.top,
    required this.left,
    required this.bottom,
    required this.right,
    required this.width,
    required this.height,
  }) : super(key: globalKey);

  @override
  _ScrollBarState createState() => _ScrollBarState();
}

class _ScrollBarState extends State<ScrollBar> {
  double position = -1;
  double downPos = 0;
  Timer? scrollTimer;
  Color handleColor = Colors.white;
  bool entered = false;
  bool tap2 = false;
  double scrollFactor = 1;
  double _lastBuildSize = 0;

  void updateScroll(double delta, {bool updateGrid = true}) {
    position += delta;
    _fixPos();
    update();
    widget.onUpdate(position * scrollFactor, updateGrid: updateGrid);
  }

  void update() {
    if (!mounted) return;
    setState(() {});
  }

  void _fixPos() {
    if (position < 0)
      position = 0;
    else if (position + widget.handleSize > 1) position = 1 - widget.handleSize;
  }

  @override
  Widget build(BuildContext context) {
    final isVertical = widget.orientation == ScrollBarOrientation.vertical;

    return Positioned(
      top: widget.top,
      bottom: widget.bottom,
      left: widget.left,
      right: widget.right,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, box) {
            double handleHeight = 0;
            double handleWidth = 0;
            double defaultHandleHeight = 0;
            double defaultHandleWidth = 0;
            scrollFactor = 1;
            final offset = 20;
            late double buildSize;

            if (isVertical) {
              buildSize = box.maxHeight - 40;
              defaultHandleHeight = widget.handleSize * buildSize;
              handleWidth = 0.6 * box.maxWidth;

              handleHeight = max(30, defaultHandleHeight);
              scrollFactor = (buildSize - defaultHandleHeight) /
                  (buildSize - handleHeight);
              widget.handleSize *= handleHeight / defaultHandleHeight;
            } else {
              buildSize = box.maxWidth - 40;
              defaultHandleWidth = widget.handleSize * buildSize;
              handleHeight = 0.6 * box.maxHeight;

              handleWidth = max(30, defaultHandleWidth);
              scrollFactor =
                  (buildSize - defaultHandleWidth) / (buildSize - handleWidth);
              widget.handleSize *= handleWidth / defaultHandleWidth;
            }

            if (_lastBuildSize != 0 && buildSize > _lastBuildSize) {
              position *= buildSize / _lastBuildSize;
            }

            _lastBuildSize = buildSize;

            _fixPos();

            double _get_pos(dynamic details) {
              if (isVertical) return details.localPosition.dy;
              return details.localPosition.dx;
            }

            double _box_size(BoxConstraints box) {
              if (isVertical) return box.maxHeight - 40;
              return box.maxWidth - 40;
            }

            if (tap2 || entered) {
              handleColor = Colors.grey;
            } else {
              handleColor = Colors.white;
            }

            return Listener(
              onPointerDown: (details) {
                if (tap2) return;

                if (scrollTimer == null) {
                  final downPos_ =
                      (_get_pos(details) - offset) / _box_size(box);
                  final delta = (downPos_ - position) / 10;

                  scrollTimer =
                      Timer.periodic(Duration(milliseconds: 16), (timer) {
                        position += delta;
                        if ((position - downPos_).abs() < delta.abs()) {
                          position = downPos_;
                          timer.cancel();
                          scrollTimer = null;
                        }
                        _fixPos();
                        update();
                        widget.onUpdate(position * scrollFactor, updateGrid: true);
                      });
                }
              },
              onPointerUp: (details) {
                if (tap2) return;
                if (scrollTimer != null) {
                  scrollTimer!.cancel();
                  scrollTimer = null;
                }
              },
              child: Container(
                color: Colors.grey.shade300,
                child: Stack(
                  children: [
                    Positioned(
                      top: isVertical ? 0 : null,
                      left: 0,
                      bottom: isVertical ? null : 0,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: Container(
                          color: Colors.blue,
                          child: isVertical
                              ? Icon(Icons.arrow_drop_up_outlined)
                              : Icon(Icons.arrow_left_outlined),
                        ),
                      ),
                    ),
                    Positioned(
                      left: isVertical ? 0 : null,
                      bottom: 0,
                      right: isVertical ? null : 0,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: Container(
                          color: Colors.blue,
                          child: isVertical
                              ? Icon(Icons.arrow_drop_down_outlined)
                              : Icon(Icons.arrow_right_outlined),
                        ),
                      ),
                    ),
                    Positioned(
                        top: isVertical
                            ? (position) * _box_size(box) + offset
                            : null,
                        left: isVertical
                            ? 0.5 * (box.maxWidth - handleWidth)
                            : (position) * _box_size(box) + offset,
                        bottom: isVertical
                            ? null
                            : 0.5 * (box.maxHeight - handleHeight),
                        child: SizedBox(
                          width: handleWidth,
                          height: handleHeight,
                          child: Listener(
                            onPointerDown: (details) {
                              tap2 = true;
                              downPos = _get_pos(details);
                              update();
                            },
                            onPointerUp: (details) {
                              // position += delta;
                              tap2 = false;
                              entered = false;
                              update();
                            },
                            onPointerMove: (details) {
                              final currentPos = _get_pos(details);
                              final delta =
                                  (currentPos - downPos) / _box_size(box);
                              position += delta;
                              _fixPos();
                              downPos = currentPos;
                              widget.onUpdate(position * scrollFactor);
                            },
                            child: MouseRegion(
                              onEnter: (details) {
                                entered = true;
                                update();
                              },
                              onExit: (details) {
                                if (tap2) return;
                                entered = false;
                                update();
                              },
                              child: Container(
                                // color: Colors.grey,
                                decoration: BoxDecoration(
                                  color: handleColor,
                                  // borderRadius: BorderRadius.only(
                                  //     topLeft: Radius.circular(10),
                                  //     topRight: Radius.circular(10),
                                  //     bottomLeft: Radius.circular(10),
                                  //     bottomRight: Radius.circular(10)),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.5),
                                      spreadRadius: 5,
                                      blurRadius: 7,
                                      offset: Offset(
                                          0, 3), // changes position of shadow
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Size _textSize(String text, TextStyle style,
    {double maxWidth = double.infinity}) {
  final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxWidth == double.infinity ? 1 : null,
      textDirection: TextDirection.ltr)
    ..layout(minWidth: 0, maxWidth: maxWidth);
  return textPainter.size;
}

class GrowingTextField extends StatefulWidget {
  double left;
  double top;
  double width;
  double height;
  String text;
  TextStyle style;
  BoxDecoration decoration;
  late TextEditingController controller;
  double maxWidth;
  FocusNode focusNode;
  void Function(Index, String, bool) submitData;
  Index index;
  bool autoFocus;
  TableSelection tableSelection;
  FocusNode tableFocusNode;
  _GrowingTextFieldState? state;

  GrowingTextField({
    Key? key,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.text,
    required this.style,
    required this.decoration,
    this.maxWidth = 200,
    required this.focusNode,
    required this.submitData,
    required this.index,
    required this.autoFocus,
    required this.tableSelection,
    required this.tableFocusNode,
  }) : super(key: key) {
    controller = TextEditingController(text: text);
    maxWidth = max(maxWidth, width);
  }

  void updateData(
      {required double left,
        required double top,
        required double width,
        required double height,
        required String text,
        required TextStyle style,
        required BoxDecoration decoration,
        required FocusNode focusNode,
        required void Function(Index, String, bool) submitData,
        required Index index,
        required bool autoFocus,
        required TableSelection tableSelection,
        required FocusNode tableFocusNode,
        double maxWidth = 200}) {
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
    this.text = text;
    this.style = style;
    this.decoration = decoration;
    this.focusNode = focusNode;
    this.submitData = submitData;
    this.index = index;
    this.autoFocus = autoFocus;
    this.tableSelection = tableSelection;
    this.tableFocusNode = tableFocusNode;
    this.maxWidth = maxWidth;

    controller = TextEditingController(text: text);
    maxWidth = max(maxWidth, width);
    state = null;
  }

  void setText(String txt) {
    focusNode.requestFocus();
    controller.text = txt;
    update();
  }

  void update() {
    state?.update();
  }

  @override
  _GrowingTextFieldState createState() {
    if (state == null) {
      state = _GrowingTextFieldState();
    }
    return state!;
  }
}

class _GrowingTextFieldState extends State<GrowingTextField> {
  // late TextEditingController controller;
  double originalHeight = 0;
  bool changeSelection = true;
  int selectionPosition = -1;

  @override
  void initState() {
    super.initState();
    originalHeight = widget.height;
    // controller = TextEditingController(text: widget.text);
  }

  void update() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final size = _textSize(widget.controller.text, widget.style,
        maxWidth: widget.maxWidth);

    widget.width = max(widget.width, size.width + 10);
    widget.height = max(size.height, originalHeight); // + originalHeight * 0;

    if (selectionPosition == -1)
      selectionPosition = widget.controller.text.length;

    // print(widget.controller.selection);

    if (changeSelection) {
      widget.controller.selection = TextSelection.fromPosition(TextPosition(
          offset: min(selectionPosition, widget.controller.text.length)));
    }

    // print(selectionPosition);
    // widget.controller.selection = TextSelection.collapsed(offset: selectionPosition);

    // print(widget.controller.selection);

    changeSelection = true;

    if (widget.autoFocus) {
      // widget.tableFocusNode.unfocus();
      widget.focusNode.requestFocus();
    }

    final onKey = (FocusNode node, RawKeyEvent event) {
      if (event is RawKeyUpEvent) return true;

      // print(event);

      final keyLabel = event.logicalKey.keyLabel;

      if (keyLabel == 'Arrow Up') {
        changeSelection = false;
        widget.tableSelection.focusUp();
        widget.submitData(widget.index, widget.controller.text, true);
        return KeyEventResult.handled;
      } else if (keyLabel == 'Arrow Down') {
        changeSelection = false;
        widget.tableSelection.focusDown();
        widget.submitData(widget.index, widget.controller.text, true);
        return KeyEventResult.handled;
      } else if (keyLabel == 'Enter') {
        changeSelection = false;
        widget.submitData(widget.index, widget.controller.text, true);
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    };

    widget.focusNode.onKey = onKey;

    // widget.focusNode.requestFocus();

    return Positioned(
      top: widget.top,
      left: widget.left,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Container(
          margin: const EdgeInsets.all(0),
          padding: const EdgeInsets.only(left: 5),
          decoration: widget.decoration,
          child: TextField(
            // decoration: InputDecoration.collapsed(
            //   hintText: '',
            //   floatingLabelBehavior: FloatingLabelBehavior.never,
            //
            // ),
            // textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.only(
                  top: 3, left: -1), // FIXME: shouldn't have to do this
            ),
            // expands: true,
            // decoration: InputDecoration(
            //   prefixIcon: null,
            //   isCollapsed: true,
            // ),
            controller: widget.controller,
            // backgroundCursorColor: widget.style.color!,

            cursorColor: widget.style.color!,
            focusNode: widget.focusNode,
            // focusNode: FocusNode(),
            autofocus: false,
            // showCursor: true,
            style: widget.style,
            maxLines: 100,
            onChanged: (data) {
              changeSelection = false;
              update();
            },
          ),
        ),
      ),
      // ),
    );
  }
}

