declare const __FORKOP_RUSSIAN__: string;
const russian: Record<string, string> = JSON.parse(__FORKOP_RUSSIAN__);
const storageKey = 'forkop.interfaceLanguage';

export function getForkopLanguage(): 'ru' | 'en' {
  try {
    const value = localStorage.getItem(storageKey);
    if (value === 'ru' || value === 'en') return value;
  } catch {
    /* Use LuCI's language when browser storage is unavailable. */
  }
  // Until a language is chosen, follow LuCI's language.
  return document.documentElement.lang.toLowerCase().split('-')[0] === 'ru'
    ? 'ru'
    : 'en';
}

export function setForkopLanguage(language: 'ru' | 'en') {
  localStorage.setItem(storageKey, language);
}

export function translateForkop(text: string): string {
  return getForkopLanguage() === 'ru' ? russian[text] || text : text;
}

// esbuild injects this local binding only into Forkop's bundle.
export { translateForkop as _ };
