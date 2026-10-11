import { describe, expect, it } from 'vitest';
import { customRulesetTag, customRulesetLabel } from './rulesetLabels';
import { formatRouteReason } from './routeReason';

describe('custom rule-set monitoring labels', () => {
  it('maps the router Twitch reference to its exact generated tag', () => {
    const reference =
      'https://mirror.51343.ru/forkop/lists/b4geoip-forkop/srs/twitch.srs';
    const tag = customRulesetTag(reference);
    expect(tag).toBe('inline-custom-9a48d2723796-ruleset');
    expect(
      formatRouteReason(
        `rule_set=${tag} => route(VPN-out)`,
        '',
        undefined,
        undefined,
        { [tag]: customRulesetLabel(reference) },
      ),
    ).toBe('Twitch');
  });
  it('uses filenames without URL query credentials and preserves exact evidence', () => {
    expect(customRulesetLabel('/etc/lists/custom.json')).toBe('Custom');
    expect(
      customRulesetLabel('https://example.org/list.srs?token=secret'),
    ).toBe('List');
    expect(
      formatRouteReason(
        'rule_set=custom',
        'domain_suffix=ttvnw.net',
        undefined,
        undefined,
        { custom: 'Twitch' },
      ),
    ).toBe('domain_suffix=ttvnw.net');
  });
});
