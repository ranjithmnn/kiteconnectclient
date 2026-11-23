import 'package:material_ui/material_ui.dart';
import 'package:native_dialog_plus/native_dialog_plus.dart';

class DialogUtil {
  static void showSimpleDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    NativeDialogPlus(
      actions: [
        NativeDialogPlusAction(
          text: 'Ok',
          onPressed: () {},
          style: NativeDialogPlusActionStyle.defaultStyle,
        ),
      ],
      title: title,
      message: message,
    ).show();
  }
}
