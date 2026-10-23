// Forkop's catalog contains singular, context-free gettext entries.
export function readTranslations(po: string): Record<string, string> {
  const translations: Record<string, string> = {};
  let id = '';
  let value = '';
  let field = '';
  let fuzzy = false;
  function flush() {
    if (id && value && !fuzzy) translations[id] = value;
    id = value = field = '';
    fuzzy = false;
  }
  for (const line of `${po}\n\n`.split(/\r?\n/)) {
    if (!line.trim()) {
      flush();
      continue;
    }
    if (line.startsWith('#,')) fuzzy ||= line.includes('fuzzy');
    if (line.startsWith('#')) continue;
    const match = /^(msgid|msgstr)\s+(".*")$/.exec(line);
    if (match) {
      field = match[1];
      if (field === 'msgid') id = JSON.parse(match[2]);
      else value = JSON.parse(match[2]);
    } else if (line.startsWith('"')) {
      if (field === 'msgid') id += JSON.parse(line);
      if (field === 'msgstr') value += JSON.parse(line);
    } else {
      throw new Error(`Unsupported Forkop translation entry: ${line}`);
    }
  }
  return translations;
}
