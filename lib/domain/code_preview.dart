import 'dart:convert';
import 'dart:typed_data';

const codeLanguages = {
  'cpp': 'cpp',
  'cc': 'cpp',
  'cxx': 'cpp',
  'hpp': 'cpp',
  'hxx': 'cpp',
  'c': 'cpp',
  'h': 'cpp',
  'cs': 'cs',
  'py': 'python',
  'js': 'javascript',
  'mjs': 'javascript',
  'jsx': 'javascript',
  'ts': 'typescript',
  'tsx': 'typescript',
  'dart': 'dart',
  'java': 'java',
  'kt': 'kotlin',
  'kts': 'kotlin',
  'rs': 'rust',
  'go': 'go',
  'swift': 'swift',
  'rb': 'ruby',
  'php': 'php',
  'sh': 'bash',
  'bash': 'bash',
  'ps1': 'powershell',
  'sql': 'sql',
  'json': 'json',
  'yaml': 'yaml',
  'yml': 'yaml',
  'xml': 'xml',
  'html': 'xml',
  'htm': 'xml',
  'css': 'css',
  'scss': 'scss',
  'md': 'markdown',
  'txt': '',
  'log': '',
  'csv': '',
  'toml': 'ini',
  'ini': 'ini',
  'r': 'r',
  'lua': 'lua',
  'tex': 'latex',
};
String? previewLanguage(String name) =>
    codeLanguages[name.split('.').last.toLowerCase()];

/// Strict decoding: never present replacement characters as original source.
String decodeCodePreview(Uint8List bytes) {
  if (bytes.length > 1024 * 1024) {
    throw const FormatException(
      'Preview supports files up to 1 MiB. Open the original for larger files.',
    );
  }
  if (bytes.contains(0)) {
    throw const FormatException(
      'This file is binary or uses an unsupported encoding. Open the original.',
    );
  }
  return utf8.decode(bytes);
}
