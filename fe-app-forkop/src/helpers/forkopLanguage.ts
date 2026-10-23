declare const __FORKOP_RUSSIAN__: string;
const russian: Record<string, string> = JSON.parse(__FORKOP_RUSSIAN__);
const storageKey = 'forkop.interfaceLanguage';

export function getForkopLanguage(): 'ru' | 'en' | 'auto' {
  try {
    const value = localStorage.getItem(storageKey);
    if (value === 'ru' || value === 'en') return value;
  } catch {
    /* Use LuCI's language when browser storage is unavailable. */
  }
  return 'auto';
}

export function setForkopLanguage(language: 'ru' | 'en' | 'auto') {
  if (language === 'auto') localStorage.removeItem(storageKey);
  else localStorage.setItem(storageKey, language);
}

export function translateForkop(text: string): string {
  const preference = getForkopLanguage();
  const language =
    preference === 'auto'
      ? document.documentElement.lang.toLowerCase().split('-')[0]
      : preference;
  return language === 'ru' ? russian[text] || text : text;
}

// esbuild injects this local binding only into Forkop's bundle.
export { translateForkop as _ };
