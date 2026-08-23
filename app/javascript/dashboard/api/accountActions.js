/* global axios */

import ApiClient from './ApiClient';

class AccountActions extends ApiClient {
  constructor() {
    super('actions', { accountScoped: true });
  }

  merge(parentId, childId) {
    return axios.post(`${this.url}/contact_merge`, {
      base_contact_id: parentId,
      mergee_contact_id: childId,
    });
  }

  mergeAgents({ baseAgentId, mergeeAgentId, email }) {
    return axios.post(`${this.url}/agent_merge`, {
      base_agent_id: baseAgentId,
      mergee_agent_id: mergeeAgentId,
      email,
    });
  }
}

export default new AccountActions();
