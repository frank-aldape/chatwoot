<script setup>
import { useAlert } from 'dashboard/composables';
import { computed, onMounted, ref } from 'vue';
import Avatar from 'next/avatar/Avatar.vue';
import { useI18n } from 'vue-i18n';
import {
  useStoreGetters,
  useStore,
  useMapGetter,
} from 'dashboard/composables/store';

import AddAgent from './AddAgent.vue';
import EditAgent from './EditAgent.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import AgentAPI from 'dashboard/api/agents';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const loading = ref({});
const resendLoading = ref({});
const showAddPopup = ref(false);
const showDeletePopup = ref(false);
const showEditPopup = ref(false);
const agentAPI = ref({ message: '' });
const currentAgent = ref({});
const searchQuery = ref('');

const deleteConfirmText = computed(
  () => `${t('AGENT_MGMT.DELETE.CONFIRM.YES')} ${currentAgent.value.name}`
);
const deleteRejectText = computed(() => {
  return `${t('AGENT_MGMT.DELETE.CONFIRM.NO')} ${currentAgent.value.name}`;
});
const deleteMessage = computed(() => {
  return ` ${currentAgent.value.name}?`;
});

const agentList = computed(() => getters['agents/getAgents'].value);
const uiFlags = computed(() => getters['agents/getUIFlags'].value);
const currentUserId = computed(() => getters.getCurrentUserID.value);
const customRoles = useMapGetter('customRole/getCustomRoles');

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('customRole/getCustomRole');
});

const findCustomRole = agent =>
  customRoles.value.find(role => role.id === agent.custom_role_id);

const getAgentRoleName = agent => {
  if (!agent.custom_role_id) {
    return t(`AGENT_MGMT.AGENT_TYPES.${agent.role.toUpperCase()}`);
  }
  const customRole = findCustomRole(agent);
  return customRole ? customRole.name : '';
};

const getAgentRolePermissions = agent => {
  if (!agent.custom_role_id) {
    return [];
  }
  const customRole = findCustomRole(agent);
  return customRole?.permissions || [];
};

const getAgentVerificationLabel = agent => {
  return agent.confirmed
    ? t('AGENT_MGMT.LIST.VERIFIED')
    : t('AGENT_MGMT.LIST.VERIFICATION_PENDING');
};

const getAgentInvitationMeta = agent => {
  if (agent.confirmed || !agent.confirmation_sent_at) {
    return '';
  }

  return t('AGENT_MGMT.LIST.INVITATION_SENT_AT', {
    date: new Date(agent.confirmation_sent_at).toLocaleString(),
  });
};

const getAgentSearchFields = agent => {
  return [
    agent.name,
    agent.email,
    agent.role,
    getAgentRoleName(agent),
    getAgentVerificationLabel(agent),
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();
};

const filteredAgentList = computed(() => {
  const normalizedSearch = searchQuery.value.trim().toLowerCase();

  if (!normalizedSearch) {
    return agentList.value;
  }

  return agentList.value.filter(agent =>
    getAgentSearchFields(agent).includes(normalizedSearch)
  );
});

const hasActiveSearch = computed(() => searchQuery.value.trim().length > 0);
const hasRecords = computed(() => (agentList.value || []).length > 0);
const showNoRecordsFound = computed(
  () => !hasRecords.value && !hasActiveSearch.value
);
const showEmptySearchResults = computed(
  () => hasActiveSearch.value && (filteredAgentList.value || []).length === 0
);

const verifiedAdministrators = computed(() => {
  return agentList.value.filter(
    agent => agent.role === 'administrator' && agent.confirmed
  );
});

const showEditAction = agent => {
  return currentUserId.value !== agent.id;
};

const showDeleteAction = agent => {
  if (currentUserId.value === agent.id) {
    return false;
  }

  if (!agent.confirmed) {
    return true;
  }

  if (agent.role === 'administrator') {
    return verifiedAdministrators.value.length !== 1;
  }
  return true;
};

const showResendInvitationAction = agent => {
  return !agent.confirmed;
};

const showAlertMessage = message => {
  loading.value[currentAgent.value.id] = false;
  currentAgent.value = {};
  agentAPI.value.message = message;
  useAlert(message);
};

const resendInvitation = async agent => {
  resendLoading.value[agent.id] = true;

  try {
    await AgentAPI.resendInvitation(agent.id);
    useAlert(t('AGENT_MGMT.RESEND_INVITATION.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('AGENT_MGMT.RESEND_INVITATION.API.ERROR_MESSAGE'));
  } finally {
    resendLoading.value[agent.id] = false;
  }
};

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = agent => {
  showEditPopup.value = true;
  currentAgent.value = agent;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openDeletePopup = agent => {
  showDeletePopup.value = true;
  currentAgent.value = agent;
};
const closeDeletePopup = () => {
  showDeletePopup.value = false;
};

const deleteAgent = async id => {
  try {
    await store.dispatch('agents/delete', id);
    showAlertMessage(t('AGENT_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    showAlertMessage(t('AGENT_MGMT.DELETE.API.ERROR_MESSAGE'));
  }
};
const confirmDeletion = () => {
  loading.value[currentAgent.value.id] = true;
  closeDeletePopup();
  deleteAgent(currentAgent.value.id);
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('AGENT_MGMT.LOADING')"
    :no-records-found="showNoRecordsFound"
    :no-records-message="$t('AGENT_MGMT.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('AGENT_MGMT.HEADER')"
        :description="$t('AGENT_MGMT.DESCRIPTION')"
        :link-text="$t('AGENT_MGMT.LEARN_MORE')"
        feature-name="agents"
      >
        <template #actions>
          <Button
            icon="i-lucide-circle-plus"
            :label="$t('AGENT_MGMT.HEADER_BTN_TXT')"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #preBody>
      <div class="mb-4 max-w-md">
        <Input
          v-model="searchQuery"
          type="search"
          :aria-label="$t('AGENT_MGMT.SEARCH.PLACEHOLDER')"
          :placeholder="$t('AGENT_MGMT.SEARCH.PLACEHOLDER')"
          :custom-input-class="[
            'h-10 [&:not(.focus)]:!border-transparent bg-n-alpha-2 ltr:!pl-9 rtl:!pr-9',
          ]"
        >
          <template #prefix>
            <Icon
              icon="i-lucide-search"
              class="absolute -translate-y-1/2 text-n-slate-11 size-4 top-1/2 ltr:left-3 rtl:right-3"
            />
          </template>
        </Input>
      </div>
    </template>
    <template #body>
      <p
        v-if="showEmptySearchResults"
        class="flex items-center justify-center py-16 text-base text-n-slate-11"
      >
        {{ $t('AGENT_MGMT.SEARCH.NO_RESULTS') }}
      </p>
      <table v-else class="divide-y divide-n-weak">
        <tbody class="divide-y divide-n-weak text-n-slate-11">
          <tr v-for="(agent, index) in filteredAgentList" :key="agent.email">
            <td class="py-4 ltr:pr-4 rtl:pl-4">
              <div class="flex flex-row items-center gap-4">
                <Avatar
                  :src="agent.thumbnail"
                  :name="agent.name"
                  :status="agent.availability_status"
                  :size="40"
                  hide-offline-status
                  rounded-full
                />
                <div>
                  <span class="block font-medium capitalize">
                    {{ agent.name }}
                  </span>
                  <span>{{ agent.email }}</span>
                </div>
              </div>
            </td>

            <td class="relative py-4 ltr:pr-4 rtl:pl-4">
              <span
                class="block font-medium w-fit"
                :class="{
                  'hover:text-gray-900 group cursor-pointer':
                    agent.custom_role_id,
                }"
              >
                {{ getAgentRoleName(agent) }}

                <div
                  class="absolute left-0 z-10 hidden max-w-[300px] w-auto bg-white rounded-xl border border-n-weak shadow-lg top-14 md:top-12 dark:bg-n-solid-2"
                  :class="{ 'group-hover:block': agent.custom_role_id }"
                >
                  <div class="flex flex-col gap-1 p-4">
                    <span class="font-semibold">
                      {{ $t('AGENT_MGMT.LIST.AVAILABLE_CUSTOM_ROLE') }}
                    </span>
                    <ul class="pl-4 mb-0 list-disc">
                      <li
                        v-for="permission in getAgentRolePermissions(agent)"
                        :key="permission"
                        class="font-normal"
                      >
                        {{
                          $t(
                            `CUSTOM_ROLE.PERMISSIONS.${permission.toUpperCase()}`
                          )
                        }}
                      </li>
                    </ul>
                  </div>
                </div>
              </span>
            </td>
            <td class="py-4 ltr:pr-4 rtl:pl-4">
              <span class="block">
                {{ getAgentVerificationLabel(agent) }}
              </span>
              <span
                v-if="getAgentInvitationMeta(agent)"
                class="block mt-1 text-xs text-n-slate-10"
              >
                {{ getAgentInvitationMeta(agent) }}
              </span>
            </td>
            <td class="py-4">
              <div class="flex justify-end gap-1">
                <Button
                  v-if="showResendInvitationAction(agent)"
                  v-tooltip.top="$t('AGENT_MGMT.RESEND_INVITATION.BUTTON_TEXT')"
                  :aria-label="$t('AGENT_MGMT.RESEND_INVITATION.BUTTON_TEXT')"
                  icon="i-lucide-mail"
                  slate
                  xs
                  faded
                  :is-loading="resendLoading[agent.id]"
                  @click="resendInvitation(agent)"
                />
                <Button
                  v-if="showEditAction(agent)"
                  v-tooltip.top="$t('AGENT_MGMT.EDIT.BUTTON_TEXT')"
                  :aria-label="$t('AGENT_MGMT.EDIT.BUTTON_TEXT')"
                  icon="i-lucide-pen"
                  slate
                  xs
                  faded
                  @click="openEditPopup(agent)"
                />
                <Button
                  v-if="showDeleteAction(agent)"
                  v-tooltip.top="$t('AGENT_MGMT.DELETE.BUTTON_TEXT')"
                  :aria-label="$t('AGENT_MGMT.DELETE.BUTTON_TEXT')"
                  icon="i-lucide-trash-2"
                  xs
                  ruby
                  faded
                  :is-loading="loading[agent.id]"
                  @click="openDeletePopup(agent, index)"
                />
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddAgent @close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditAgent
        v-if="showEditPopup"
        :id="currentAgent.id"
        :name="currentAgent.name"
        :provider="currentAgent.provider"
        :type="currentAgent.role"
        :email="currentAgent.email"
        :availability="currentAgent.availability_status"
        :custom-role-id="currentAgent.custom_role_id"
        :team-ids="currentAgent.team_ids || []"
        @close="hideEditPopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeletePopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('AGENT_MGMT.DELETE.CONFIRM.TITLE')"
      :message="$t('AGENT_MGMT.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
    />
  </SettingsLayout>
</template>
