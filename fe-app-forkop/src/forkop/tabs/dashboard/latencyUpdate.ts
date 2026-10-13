import type { StoreType } from '../../services/store.service';

type Sections = StoreType['sectionsWidget'];

export function canUpdateDashboardLatenciesInline(
  prev: Sections,
  next: Sections,
) {
  const structure = (widget: Sections) => ({
    ...widget,
    data: widget.data.map((section) => ({
      ...section,
      outbounds: section.outbounds.map((outbound) => {
        const rest: Partial<typeof outbound> = { ...outbound };
        delete rest.latency;
        return rest;
      }),
    })),
  });
  return (
    !next.loading &&
    !next.failed &&
    JSON.stringify(structure(prev)) === JSON.stringify(structure(next))
  );
}

export function getDashboardLatencyClass(latency: number) {
  const suffix = !latency
    ? 'empty'
    : latency < 800
      ? 'green'
      : latency < 1500
        ? 'yellow'
        : 'red';
  return `fkp_dashboard-page__outbound-grid__item__latency--${suffix}`;
}
