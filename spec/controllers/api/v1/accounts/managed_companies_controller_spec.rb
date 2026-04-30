require 'rails_helper'

RSpec.describe 'Managed Companies API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  describe 'POST /api/v1/accounts/{account.id}/managed_companies' do
    it 'creates a managed company with manual domain validation fields' do
      post "/api/v1/accounts/#{account.id}/managed_companies",
           params: {
             managed_company: {
               name: 'ACME',
               authorized_domain: 'acme.com',
               status: 'active',
               dns_status: 'valid',
               spf_valid: true,
               dkim_valid: true
             }
           },
           headers: administrator.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['authorized_domain']).to eq('acme.com')
      expect(response.parsed_body['dns_status']).to eq('valid')
      expect(response.parsed_body['spf_valid']).to be(true)
      expect(response.parsed_body['dkim_valid']).to be(true)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/managed_companies/:id' do
    let(:managed_company) { create(:managed_company, account: account, dns_status: :unchecked, spf_valid: false, dkim_valid: false) }

    it 'updates the stored domain validation configuration' do
      patch "/api/v1/accounts/#{account.id}/managed_companies/#{managed_company.id}",
            params: {
              managed_company: {
                dns_status: 'valid',
                spf_valid: true,
                dkim_valid: true
              }
            },
            headers: administrator.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(managed_company.reload.dns_status).to eq('valid')
      expect(managed_company.spf_valid).to be(true)
      expect(managed_company.dkim_valid).to be(true)
    end
  end
end
