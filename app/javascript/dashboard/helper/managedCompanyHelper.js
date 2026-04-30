export const getManagedCompanyInboxes = (managedCompanyId, inboxes = []) => {
  if (!managedCompanyId) {
    return [];
  }

  return inboxes.filter(
    inbox => String(inbox.managed_company?.id) === String(managedCompanyId)
  );
};

export const buildManagedCompanyInboxSummary = (inboxes = [], limit = 2) => {
  const visibleInboxes = inboxes.filter(inbox => inbox?.name);
  const totalCount = visibleInboxes.length;

  if (!totalCount) {
    return {
      names: '',
      remainingCount: 0,
      totalCount: 0,
    };
  }

  const names = visibleInboxes
    .slice(0, limit)
    .map(inbox => inbox.name)
    .join(', ');

  return {
    names,
    remainingCount: Math.max(totalCount - limit, 0),
    totalCount,
  };
};
