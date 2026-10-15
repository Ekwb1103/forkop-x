import { readFileSync } from 'node:fs';
import { describe, expect, it, vi } from 'vitest';
import { getLogErrorMessage } from '../src/forkop/services/logErrorMessage.service';

const source = readFileSync(new URL('../../luci-app-forkop/htdocs/luci-static/resources/view/forkop/whatsapp.js', import.meta.url), 'utf8');

function harness() {
  const settings = { whatsapp_real_dns: '1' };
  const meta = { '.name': 'vpn', enabled: '1', action: 'connection', community_lists: ['meta'] };
  const sections: Record<string, unknown>[] = [meta];
  const notify = vi.fn();
  const guard = new Function('baseclass', 'uci', 'ui', 'E', '_', source)(
    { extend: (value: unknown) => value },
    { get: () => settings, sections: () => sections },
    { addNotification: notify },
    (_tag: string, _attrs: unknown, text: string) => text,
    (text: string) => `translated:${text}`,
  );
  return { settings, meta, sections, notify, guard };
}

describe('WhatsApp settings save protection', () => {
  it('blocks deleting the last eligible Meta section with a translated warning', () => {
    const { guard, notify } = harness();
    expect(() => guard.assertConfiguration('vpn')).toThrow('translated:');
    expect(notify).toHaveBeenCalledWith('translated:WhatsApp DNS settings need attention', expect.stringContaining('turn off real IPs'), 'warning');
  });

  it('allows deleting Meta when another eligible section remains or the flag is off', () => {
    const { guard, sections, settings } = harness();
    sections.push({ '.name': 'other', action: 'connection', community_lists: 'meta' });
    expect(() => guard.assertConfiguration('vpn')).not.toThrow();
    sections.pop();
    settings.whatsapp_real_dns = '0';
    expect(() => guard.assertConfiguration('vpn')).not.toThrow();
  });

  it.each([
    { enabled: '0' }, { action: 'dns' }, { community_lists: [] },
    { source_ip_cidr: ['192.0.2.1'] }, { source_ip_cidr_text: '192.0.2.1' },
    { ports: ['443'] }, { ports_text: '443' },
  ])('rejects removing eligibility: %j', (change) => {
    const { guard, meta } = harness();
    expect(guard.configurationError({ whatsapp_real_dns: '1' }, [{ ...meta, ...change }])).toContain('translated:');
  });

  it('validates parsed fields before persisting, including silent modal saves', async () => {
    const { guard, meta, notify } = harness();
    const persist = vi.fn();
    const map = {
      save: async (callback: (() => Promise<void>) | null, _silent?: boolean) => {
        meta.community_lists = [];
        await callback?.();
        persist();
      },
    };
    guard.configureMap(map);
    guard.configureMap(map);
    await expect(map.save(null, true)).rejects.toThrow('Restore Meta');
    expect(persist).not.toHaveBeenCalled();
    expect(notify).toHaveBeenCalledTimes(1);
  });

  it('allows turning the flag off and removing Meta in the same save', async () => {
    const { guard, meta, settings } = harness();
    const persist = vi.fn();
    const map = {
      save: async (callback: (() => Promise<void>) | null) => {
        meta.community_lists = [];
        settings.whatsapp_real_dns = '0';
        await callback?.();
        persist();
      },
    };
    guard.configureMap(map);
    await map.save(null);
    expect(persist).toHaveBeenCalledOnce();
  });
});

describe('WhatsApp English and Russian error messages', () => {
  const po = readFileSync(new URL('../../luci-app-forkop/po/ru/forkop.po', import.meta.url), 'utf8');
  const translations = new Map([...po.matchAll(/^msgid ("[^\n]*")\r?\nmsgstr ("[^\n]*")/gm)]
    .map((match) => [JSON.parse(match[1]), JSON.parse(match[2])]));

  it.each(['en', 'ru'])('renders actionable errors in %s', (language) => {
    const translate = (text: string) => language === 'ru' ? translations.get(text) || text : text;
    vi.stubGlobal('_', translate);
    try {
      const prerequisite = getLogErrorMessage('WhatsApp real DNS requires the Meta community list');
      const cache = getLogErrorMessage('WhatsApp real DNS requires downloaded Meta subnet rules');
      const guard = new Function('baseclass', '_', source)({ extend: (value: unknown) => value }, translate);
      const warning = guard.configurationError({ whatsapp_real_dns: '1' }, []);
      for (const message of [prerequisite, cache, warning, translate('WhatsApp DNS settings need attention')]) {
        expect(message).toMatch(language === 'ru' ? /[А-Яа-я]/ : /[A-Za-z]/);
      }
      expect(prerequisite).toContain(language === 'ru' ? 'Верните Meta' : 'Restore Meta');
      expect(cache).toContain(language === 'ru' ? 'Загрузите списки Meta' : 'Download the Meta lists');
    } finally {
      vi.unstubAllGlobals();
    }
  });
});
