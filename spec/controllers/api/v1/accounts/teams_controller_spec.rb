require 'rails_helper'

RSpec.describe 'Teams API', type: :request do
  let(:account) { create(:account) }
  let!(:team) { create(:team, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/teams' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/teams"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'returns all the teams' do
        get "/api/v1/accounts/#{account.id}/teams",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body.first['id']).to eq(account.teams.first.id)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/teams/{team_id}' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/teams/#{team.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'returns all the teams' do
        get "/api/v1/accounts/#{account.id}/teams/#{team.id}",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['id']).to eq(team.id)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/teams' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/teams"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'returns unathorized for agent' do
        params = { name: 'Test Team' }

        post "/api/v1/accounts/#{account.id}/teams",
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'creates a new team when its administrator' do
        params = { name: 'test-team' }

        post "/api/v1/accounts/#{account.id}/teams",
             params: params,
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(Team.count).to eq(2)
      end

      it 'creates managed company and inbox assignments when provided' do
        managed_company = create(:managed_company, account: account)
        inbox = create(:inbox, account: account, managed_company: managed_company)
        params = {
          name: 'team-with-access',
          managed_company_assignments: [
            {
              managed_company_id: managed_company.id,
              inbox_ids: [inbox.id]
            }
          ]
        }

        post "/api/v1/accounts/#{account.id}/teams",
             params: params,
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        created_team = Team.order(:id).last
        expect(created_team.managed_company_ids).to include(managed_company.id)
        expect(created_team.inbox_ids).to include(inbox.id)
      end

      it 'creates channel rules and grants matching inboxes when provided' do
        managed_company = create(:managed_company, account: account, authorized_domain: 'example.com')
        email_inbox = create(:inbox, :with_email, account: account, managed_company: managed_company)
        params = {
          name: 'team-with-email-access',
          managed_company_assignments: [
            {
              managed_company_id: managed_company.id,
              channel_keys: ['email']
            }
          ]
        }

        post "/api/v1/accounts/#{account.id}/teams",
             params: params,
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        created_team = Team.order(:id).last
        expect(created_team.team_managed_company_channel_rules.pluck(:channel_key)).to contain_exactly('email')
        expect(created_team.inbox_ids).to include(email_inbox.id)
      end
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/teams/:id' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/teams/#{team.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'returns unauthorized for agent' do
        params = { name: 'new-team' }

        put "/api/v1/accounts/#{account.id}/teams/#{team.id}",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'updates an existing team when its an administrator' do
        params = { name: 'new-team' }

        put "/api/v1/accounts/#{account.id}/teams/#{team.id}",
            params: params,
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(team.reload.name).to eq('new-team')
      end

      it 'updates managed company inbox assignments when provided' do
        managed_company = create(:managed_company, account: account)
        inbox = create(:inbox, account: account, managed_company: managed_company)
        other_inbox = create(:inbox, account: account, managed_company: managed_company)
        create(:team_managed_company, account: account, team: team, managed_company: managed_company)
        create(:team_inbox, account: account, team: team, inbox: inbox)
        params = {
          managed_company_assignments: [
            {
              managed_company_id: managed_company.id,
              inbox_ids: [other_inbox.id]
            }
          ]
        }

        put "/api/v1/accounts/#{account.id}/teams/#{team.id}",
            params: params,
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(team.reload.inbox_ids).to contain_exactly(other_inbox.id)
      end

      it 'updates channel rules and applies future matching inbox access' do
        managed_company = create(:managed_company, account: account, authorized_domain: 'example.com')
        create(:team_managed_company, account: account, team: team, managed_company: managed_company)
        params = {
          managed_company_assignments: [
            {
              managed_company_id: managed_company.id,
              channel_keys: ['email']
            }
          ]
        }

        put "/api/v1/accounts/#{account.id}/teams/#{team.id}",
            params: params,
            headers: administrator.create_new_auth_token,
            as: :json

        email_inbox = create(:inbox, :with_email, account: account, managed_company: managed_company)

        expect(response).to have_http_status(:success)
        expect(team.reload.team_managed_company_channel_rules.pluck(:channel_key)).to contain_exactly('email')
        expect(team.inbox_ids).to include(email_inbox.id)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/teams/:id' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/teams/#{team.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'return unauthorized for agent' do
        delete "/api/v1/accounts/#{account.id}/teams/#{team.id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'destroys the team when its administrator' do
        delete "/api/v1/accounts/#{account.id}/teams/#{team.id}",
               headers: administrator.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:success)
        expect(Team.count).to eq(0)
      end
    end
  end
end
