import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

describe('Forkop language isolation', () => {
  let values: Map<string, string>;
  beforeEach(() => {
    vi.resetModules();
    values = new Map();
    vi.stubGlobal(
      '__FORKOP_RUSSIAN__',
      JSON.stringify({ Settings: 'Настройки' }),
    );
    vi.stubGlobal('document', { documentElement: { lang: 'ru-RU' } });
    vi.stubGlobal('localStorage', {
      getItem: (key: string) => values.get(key) ?? null,
      setItem: (key: string, value: string) => values.set(key, value),
      removeItem: (key: string) => values.delete(key),
    });
  });
  afterEach(() => vi.unstubAllGlobals());

  it('follows LuCI until a language is chosen, then uses English independently of Russian LuCI', async () => {
    const language = await import('../forkopLanguage');
    expect(language.getForkopLanguage()).toBe('ru');
    expect(language.translateForkop('Settings')).toBe('Настройки');
    language.setForkopLanguage('en');
    expect(language.getForkopLanguage()).toBe('en');
    expect(language.translateForkop('Settings')).toBe('Settings');
    expect(document.documentElement.lang).toBe('ru-RU');
  });

  it('defaults to English for non-Russian LuCI', async () => {
    document.documentElement.lang = 'de';
    const language = await import('../forkopLanguage');
    expect(language.getForkopLanguage()).toBe('en');
    expect(language.translateForkop('Settings')).toBe('Settings');
  });

  it('uses Russian independently of English LuCI and falls back for missing translations', async () => {
    document.documentElement.lang = 'en';
    const language = await import('../forkopLanguage');
    language.setForkopLanguage('ru');
    expect(language.translateForkop('Settings')).toBe('Настройки');
    expect(language.translateForkop('Unknown')).toBe('Unknown');
    expect(document.documentElement.lang).toBe('en');
  });
});
