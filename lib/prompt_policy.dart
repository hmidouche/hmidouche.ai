const maxFileBytes = 65536;
const maxPromptCharacters = 10000;
const supportedTextExtensions = {
  'txt', 'dart', 'java', 'py', 'js', 'ts', 'json', 'yaml', 'yml',
  'md', 'log', 'csv', 'xml', 'kt',
};
bool supportsTextFile(String name) => name.contains('.') &&
    supportedTextExtensions.contains(name.split('.').last.toLowerCase());
bool fileFits(int bytes) => bytes >= 0 && bytes <= maxFileBytes;
bool promptFits(String prompt) => prompt.length <= maxPromptCharacters;
// Full rendered prompt includes system and history. Reserve 768 tokens.
bool contextFits(int? tokenCount) =>
    tokenCount != null && tokenCount >= 0 && tokenCount <= 3328;
