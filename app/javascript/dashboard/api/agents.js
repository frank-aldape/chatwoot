/* global axios */

import ApiClient from './ApiClient';

class Agents extends ApiClient {
  constructor() {
    super('agents', { accountScoped: true });
  }

  bulkInvite({ emails }) {
    return axios.post(`${this.url}/bulk_create`, {
      emails,
    });
  }

  resendInvitation(id) {
    return axios.post(`${this.url}/${id}/resend_invitation`);
  }
}

export default new Agents();
