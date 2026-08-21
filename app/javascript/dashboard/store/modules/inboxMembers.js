import InboxMembersAPI from '../../api/inboxMembers';

export const actions = {
  // Read-only: membership is derived from the teams linked to the inbox.
  get(_, { inboxId }) {
    return InboxMembersAPI.show(inboxId);
  },
};

export default {
  namespaced: true,
  actions,
};
