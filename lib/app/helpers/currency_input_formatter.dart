import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class DecimalCurrencyInputFormatter extends TextInputFormatter {
  final String? locale;
  final int maxLength;

  DecimalCurrencyInputFormatter({this.locale, this.maxLength = 15});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String newText = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (newText.contains('.')) {
      final parts = newText.split('.');
      if (parts.length > 2) return oldValue;
      if (parts[1].length > 2) {
        newText = '${parts[0]}.${parts[1].substring(0, 2)}';
      }
    }

    final String digitsOnly = newText.replaceAll('.', '');
    if (digitsOnly.length > maxLength) {
      return oldValue;
    }
    NumberFormat formatter;
    String formattedText;
    int cursorIndex = 0, cursorIndexBuffer = 0;

    if (newText.contains('.')) {
      formatter = NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: 2,
      );
      double number = double.tryParse(newText) ?? 0.0;
      formattedText = formatter.format(number);
      if (newText.endsWith('.') && !newText.endsWith('..')) {
        final intPart = int.tryParse(newText.replaceAll('.', '')) ?? 0;
        formattedText =
            '${NumberFormat.decimalPattern(locale).format(intPart)}.00';
        cursorIndexBuffer -= 2;
      }
    } else {
      formatter = NumberFormat.decimalPattern(locale);
      int number = int.tryParse(newText) ?? 0;
      if (oldValue.text.contains('.00') && !newValue.text.contains('.00')) {
        number = (number / 100).toInt();
        cursorIndexBuffer += 2;
      }
      formattedText = formatter.format(number);
    }

    cursorIndex = newValue.selection.baseOffset;
    int oldLength = newValue.text.length;
    int newLength = formattedText.length;
    cursorIndex = cursorIndex + (newLength - oldLength) + cursorIndexBuffer;

    if (oldValue.text.length - 1 == newValue.text.length &&
        oldValue.text.length == formattedText.length) {
      cursorIndex -= 1;
    } else if (oldValue.text.length + 1 == newValue.text.length &&
        oldValue.text.length == formattedText.length) {
      cursorIndex += 1;
    }
    TextEditingValue formattedValue = TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(
        offset: cursorIndex.clamp(0, formattedText.length),
      ),
    );

    // print("oldVal: ${oldValue.text}, oldLength: ${oldValue.text.length}");
    // print("newVal: ${newValue.text}, newLength: ${newValue.text.length}");
    // print(
    //   "forVal: ${formattedValue.text}, forLength: ${formattedValue.text.length}",
    // );

    return formattedValue;
  }
}
