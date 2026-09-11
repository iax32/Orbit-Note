import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as native;
import 'package:pdfrx/pdfrx.dart';
import '../domain/pdf_form_field.dart';

Future<T> _copy<T>(
  PdfDocument document,
  T Function(native.PDFium, native.FPDF_DOCUMENT) action,
) async {
  if (document.permissions != null) {
    throw UnsupportedError('Protected PDF forms are not supported.');
  }
  final bytes = await document.encodePdf();
  if (bytes.length > 64 * 1024 * 1024) {
    throw StateError('Form editing is limited to 64 MiB PDFs.');
  }
  return PdfrxEntryFunctions.instance.compute((message) {
    final (bytes, action) = message;
    final api = native.getPdfium(modulePath: Pdfrx.pdfiumModulePath);
    final buffer = calloc<Uint8>(bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    final doc = api.FPDF_LoadMemDocument64(
      buffer.cast(),
      bytes.length,
      nullptr,
    );
    try {
      if (doc == nullptr) throw StateError('Cannot open form copy');
      if (api.FPDF_GetSignatureCount(doc) > 0 ||
          api.FPDF_GetFormType(doc) > 1) {
        throw UnsupportedError('Signed and XFA forms are not supported.');
      }
      return action(api, doc);
    } finally {
      if (doc != nullptr) api.FPDF_CloseDocument(doc);
      calloc.free(buffer);
    }
  }, (bytes, action));
}

Future<List<OrbitPdfField>> readPdfFields(PdfDocument document, int page) =>
    _copy(document, (api, doc) => _fields(api, doc, page, const {}));

Future<Uint8List> applyPdfFields(
  PdfDocument document,
  Map<String, dynamic> values,
) => _copy(document, (api, doc) {
  if (values.length > 2000) throw StateError('Too many form values');
  final pages = <int>{};
  for (final key in values.keys) {
    if (!RegExp(r'^[1-9][0-9]*:[0-9]+$').hasMatch(key)) {
      throw StateError('Invalid field identity');
    }
    pages.add(int.parse(key.split(':').first));
  }
  for (final page in pages) {
    final fields = _fields(api, doc, page, values);
    for (final key in values.keys.where((key) => key.startsWith('$page:'))) {
      if (!fields.any((field) => field.id == key)) {
        throw StateError('A saved field is no longer editable');
      }
    }
  }
  final output = BytesBuilder(copy: true);
  final writer = calloc<native.FPDF_FILEWRITE>();
  final callback =
      NativeCallable<
        Int Function(
          Pointer<native.FPDF_FILEWRITE>,
          Pointer<Void>,
          UnsignedLong,
        )
      >.isolateLocal((
        Pointer<native.FPDF_FILEWRITE> self,
        Pointer<Void> data,
        int size,
      ) {
        if (output.length + size > 80 * 1024 * 1024) return 0;
        output.add(data.cast<Uint8>().asTypedList(size));
        return 1;
      }, exceptionalReturn: 0);
  try {
    writer.ref.version = 1;
    writer.ref.WriteBlock = callback.nativeFunction;
    if (api.FPDF_SaveAsCopy(doc, writer, 2) == 0) {
      throw StateError('Filled PDF encoding failed');
    }
    return output.takeBytes();
  } finally {
    callback.close();
    calloc.free(writer);
  }
});

List<OrbitPdfField> _fields(
  native.PDFium api,
  native.FPDF_DOCUMENT doc,
  int number,
  Map<String, dynamic> values,
) {
  if (number < 1 || number > api.FPDF_GetPageCount(doc)) {
    throw RangeError('PDF page');
  }
  final info = calloc<native.FPDF_FORMFILLINFO>();
  info.ref.version = 1;
  final form = api.FPDFDOC_InitFormFillEnvironment(doc, info);
  if (form == nullptr) {
    calloc.free(info);
    throw StateError('PDF form engine unavailable');
  }
  final page = api.FPDF_LoadPage(doc, number - 1);
  final result = <OrbitPdfField>[];
  try {
    if (page == nullptr) throw StateError('PDF page unavailable');
    api.FORM_OnAfterLoadPage(page, form);
    final count = api.FPDFPage_GetAnnotCount(page);
    if (count > 2000) {
      throw StateError('Too many form annotations on this page');
    }
    for (var index = 0; index < count; index++) {
      final annot = api.FPDFPage_GetAnnot(page, index);
      if (annot == nullptr) continue;
      final rect = calloc<native.FS_RECTF>();
      try {
        final type = api.FPDFAnnot_GetFormFieldType(form, annot);
        final flags = api.FPDFAnnot_GetFormFieldFlags(form, annot);
        // Ordinary text and checkboxes only; exclude read-only/password/file-select fields.
        if ((type != 2 && type != 6) ||
            (flags & (1 | 8192 | 1048576)) != 0 ||
            api.FPDFAnnot_GetRect(annot, rect) == 0) {
          continue;
        }
        final key = '$number:$index';
        if (![
              rect.ref.left,
              rect.ref.top,
              rect.ref.right,
              rect.ref.bottom,
            ].every((v) => v.isFinite) ||
            rect.ref.left >= rect.ref.right ||
            rect.ref.bottom >= rect.ref.top) {
          continue;
        }
        final value = values[key];
        if (values.containsKey(key)) {
          if ((type == 2 && value is! bool) ||
              (type == 6 && (value is! String || value.length > 10000))) {
            throw StateError('Invalid PDF field value');
          }
          if (type == 2) {
            if ((api.FPDFAnnot_IsChecked(form, annot) != 0) != value) {
              final x = (rect.ref.left + rect.ref.right) / 2;
              final y = (rect.ref.top + rect.ref.bottom) / 2;
              api.FORM_OnLButtonDown(form, page, 0, x, y);
              api.FORM_OnLButtonUp(form, page, 0, x, y);
            }
          } else {
            if (api.FORM_SetFocusedAnnot(form, annot) == 0) {
              throw StateError('Cannot focus PDF field');
            }
            api.FORM_SelectAllText(form, page);
            final text = (value as String).toNativeUtf16();
            try {
              api.FORM_ReplaceSelection(form, page, text.cast());
            } finally {
              calloc.free(text);
            }
          }
          api.FORM_ForceToKillFocus(form);
        }
        String readString(bool name) {
          final size = name
              ? api.FPDFAnnot_GetFormFieldName(form, annot, nullptr, 0)
              : api.FPDFAnnot_GetFormFieldValue(form, annot, nullptr, 0);
          if (size < 2 || size > 200002) return '';
          final buffer = calloc<Uint8>(size);
          try {
            if (name) {
              api.FPDFAnnot_GetFormFieldName(form, annot, buffer.cast(), size);
            } else {
              api.FPDFAnnot_GetFormFieldValue(form, annot, buffer.cast(), size);
            }
            return buffer.cast<Utf16>().toDartString(length: size ~/ 2 - 1);
          } finally {
            calloc.free(buffer);
          }
        }

        final current = type == 2
            ? api.FPDFAnnot_IsChecked(form, annot) != 0
            : readString(false);
        if (values.containsKey(key) && current != value) {
          throw StateError('PDF field rejected the value');
        }
        result.add(
          OrbitPdfField(
            page: number,
            index: index,
            name: readString(true),
            checkbox: type == 2,
            value: current,
            left: rect.ref.left,
            top: rect.ref.top,
            right: rect.ref.right,
            bottom: rect.ref.bottom,
          ),
        );
      } finally {
        calloc.free(rect);
        api.FPDFPage_CloseAnnot(annot);
      }
    }
  } finally {
    if (page != nullptr) {
      api.FORM_OnBeforeClosePage(page, form);
      api.FPDF_ClosePage(page);
    }
    api.FPDFDOC_ExitFormFillEnvironment(form);
    calloc.free(info);
  }
  return result;
}
