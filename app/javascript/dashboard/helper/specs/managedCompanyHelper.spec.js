import {
  buildManagedCompanyInboxSummary,
  getManagedCompanyInboxes,
} from '../managedCompanyHelper';

describe('#managedCompanyHelper', () => {
  describe('#getManagedCompanyInboxes', () => {
    it('returns only inboxes that belong to the managed company', () => {
      const inboxes = [
        {
          id: 1,
          name: 'ACME - WhatsApp - Ventas',
          managed_company: { id: 10 },
        },
        {
          id: 2,
          name: 'ACME - Correo - Dirección',
          managed_company: { id: 10 },
        },
        {
          id: 3,
          name: 'Globex - Instagram - Marketing',
          managed_company: { id: 20 },
        },
      ];

      expect(getManagedCompanyInboxes(10, inboxes)).toEqual([
        inboxes[0],
        inboxes[1],
      ]);
    });
  });

  describe('#buildManagedCompanyInboxSummary', () => {
    it('builds a compact summary and reports remaining inboxes', () => {
      const summary = buildManagedCompanyInboxSummary(
        [
          { id: 1, name: 'WhatsApp Ventas' },
          { id: 2, name: 'Correo Dirección' },
          { id: 3, name: 'Instagram Marketing' },
        ],
        2
      );

      expect(summary).toEqual({
        names: 'WhatsApp Ventas, Correo Dirección',
        remainingCount: 1,
        totalCount: 3,
      });
    });

    it('returns an empty summary when there are no inboxes', () => {
      expect(buildManagedCompanyInboxSummary()).toEqual({
        names: '',
        remainingCount: 0,
        totalCount: 0,
      });
    });
  });
});
