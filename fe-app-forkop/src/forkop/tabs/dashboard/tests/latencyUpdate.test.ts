import { describe, expect, it } from 'vitest';
import {
  canUpdateDashboardLatenciesInline,
  getDashboardLatencyClass,
} from '../latencyUpdate';
import type { StoreType } from '../../../services/store.service';

function widget(): StoreType['sectionsWidget'] {
  return {
    loading: false,
    failed: false,
    data: [
      {
        code: 'selector',
        sectionName: 'VPN',
        displayName: 'VPN',
        withTagSelect: true,
        outbounds: [
          {
            code: 'a',
            displayName: 'A',
            type: 'VLESS',
            selected: true,
            latency: 20,
          },
        ],
      },
    ],
    latencyFetchingSections: {},
    latencyProgressSections: {},
    subscriptionUpdatingSections: {},
    selectorSwitchingSections: {},
  };
}

describe('dashboard latency refresh', () => {
  it('updates latency in place but rebuilds for selection or structural changes', () => {
    const prev = widget();
    const next = structuredClone(prev);
    next.data[0].outbounds[0].latency = 1000;
    expect(canUpdateDashboardLatenciesInline(prev, next)).toBe(true);
    next.data[0].outbounds[0].selected = false;
    expect(canUpdateDashboardLatenciesInline(prev, next)).toBe(false);
    next.data[0].outbounds[0].selected = true;
    next.data[0].outbounds.push({
      code: 'b',
      displayName: 'B',
      type: 'VLESS',
      selected: false,
      latency: 30,
    });
    expect(canUpdateDashboardLatenciesInline(prev, next)).toBe(false);
  });
  it('retains unavailable and loading render states and latency colours', () => {
    const prev = widget();
    expect(
      canUpdateDashboardLatenciesInline(prev, { ...prev, failed: true }),
    ).toBe(false);
    expect(
      canUpdateDashboardLatenciesInline(prev, { ...prev, loading: true }),
    ).toBe(false);
    expect([0, 40, 900, 1800].map(getDashboardLatencyClass)).toEqual(
      ['empty', 'green', 'yellow', 'red'].map(
        (suffix) =>
          `fkp_dashboard-page__outbound-grid__item__latency--${suffix}`,
      ),
    );
  });
});
