<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store.js';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SettingsSection from '../../../../../components/SettingsSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const store = useStore();
const { t } = useI18n();

const selectedTeams = ref([]);
const isUpdating = ref(false);

const teamList = useMapGetter('teams/getTeams');
const agentList = useMapGetter('agents/getAgents');

const syncSelectedTeams = () => {
  const teamIds = props.inbox.team_ids || [];
  selectedTeams.value = teamList.value.filter(team =>
    teamIds.includes(team.id)
  );
};

onMounted(() => {
  store.dispatch('teams/get');
  store.dispatch('agents/get');
  syncSelectedTeams();
});

watch(() => props.inbox, syncSelectedTeams);
watch(teamList, syncSelectedTeams);

// Who can see this inbox, and which team is granting it. Derived from the
// agents list so there is no second source of truth to drift out of step.
const viewersByTeam = computed(() =>
  selectedTeams.value.map(team => ({
    team,
    agents: agentList.value.filter(agent =>
      (agent.team_ids || []).includes(team.id)
    ),
  }))
);

const administrators = computed(() =>
  agentList.value.filter(agent => agent.role === 'administrator')
);

const updateTeams = async () => {
  isUpdating.value = true;
  try {
    await store.dispatch('inboxes/updateInbox', {
      id: props.inbox.id,
      formData: false,
      team_ids: selectedTeams.value.map(team => team.id),
    });
    useAlert(t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
  }
  isUpdating.value = false;
};
</script>

<template>
  <div>
    <SettingsSection
      :title="t('INBOX_MGMT.SETTINGS_POPUP.INBOX_TEAMS')"
      :sub-title="t('INBOX_MGMT.SETTINGS_POPUP.INBOX_TEAMS_SUB_TEXT')"
    >
      <multiselect
        v-model="selectedTeams"
        :options="teamList"
        track-by="id"
        label="name"
        multiple
        :close-on-select="false"
        :clear-on-select="false"
        hide-selected
        :placeholder="t('FORMS.MULTISELECT.SELECT')"
        selected-label
        :select-label="t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
        :deselect-label="t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
      />

      <NextButton
        :label="t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
        :is-loading="isUpdating"
        @click="updateTeams"
      />
    </SettingsSection>

    <SettingsSection
      :title="t('INBOX_MGMT.SETTINGS_POPUP.INBOX_VIEWERS')"
      :sub-title="t('INBOX_MGMT.SETTINGS_POPUP.INBOX_VIEWERS_SUB_TEXT')"
      :show-border="false"
    >
      <div v-if="viewersByTeam.length" class="flex flex-col gap-4">
        <div v-for="entry in viewersByTeam" :key="entry.team.id">
          <p class="mb-1 text-sm font-medium text-n-slate-12">
            {{ entry.team.name }}
          </p>
          <ul
            v-if="entry.agents.length"
            class="flex flex-wrap gap-2 p-0 m-0 list-none"
          >
            <li
              v-for="agent in entry.agents"
              :key="agent.id"
              class="px-2 py-1 text-sm rounded-md bg-n-slate-3 text-n-slate-12"
            >
              {{ agent.name }}
            </li>
          </ul>
          <p v-else class="mb-0 text-sm text-n-slate-11">
            {{ t('INBOX_MGMT.SETTINGS_POPUP.INBOX_VIEWERS_TEAM_EMPTY') }}
          </p>
        </div>
      </div>
      <p v-else class="text-sm text-n-slate-11">
        {{ t('INBOX_MGMT.SETTINGS_POPUP.INBOX_VIEWERS_EMPTY') }}
      </p>

      <p class="mt-3 mb-0 text-sm text-n-slate-11">
        {{
          t('INBOX_MGMT.SETTINGS_POPUP.INBOX_VIEWERS_ADMINS', {
            count: administrators.length,
          })
        }}
      </p>
    </SettingsSection>
  </div>
</template>
