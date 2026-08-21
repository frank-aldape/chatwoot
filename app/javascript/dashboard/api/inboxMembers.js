import ApiClient from './ApiClient';

// Membership is derived from teams, so only the read endpoint is exposed.
class InboxMembers extends ApiClient {
  constructor() {
    super('inbox_members', { accountScoped: true });
  }
}

export default new InboxMembers();
