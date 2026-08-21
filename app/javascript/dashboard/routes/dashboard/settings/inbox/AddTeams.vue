<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store.js';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PageHeader from '../SettingsSubPageHeader.vue';

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const selectedTeams = ref([]);
const isCreating = ref(false);
const hasSubmitted = ref(false);

const teamList = useMapGetter('teams/getTeams');
const hasError = computed(
  () => hasSubmitted.value && !selectedTeams.value.length
);

onMounted(() => store.dispatch('teams/get'));

const addTeams = async () => {
  hasSubmitted.value = true;
  if (!selectedTeams.value.length) return;

  isCreating.value = true;
  try {
    await store.dispatch('inboxes/updateInbox', {
      id: route.params.inbox_id,
      formData: false,
      team_ids: selectedTeams.value.map(team => team.id),
    });
    router.replace({
      name: 'settings_inbox_finish',
      params: { page: 'new', inbox_id: route.params.inbox_id },
    });
  } catch (error) {
    useAlert(t('INBOX_MGMT.ADD.TEAMS.API_ERROR'));
  }
  isCreating.value = false;
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <form class="flex flex-wrap flex-col mx-0" @submit.prevent="addTeams()">
      <div class="w-full">
        <PageHeader
          :header-title="t('INBOX_MGMT.ADD.TEAMS.TITLE')"
          :header-content="t('INBOX_MGMT.ADD.TEAMS.DESC')"
        />
      </div>
      <div>
        <div class="w-full">
          <label :class="{ error: hasError }">
            {{ t('INBOX_MGMT.ADD.TEAMS.TITLE') }}
            <multiselect
              v-model="selectedTeams"
              :options="teamList"
              track-by="id"
              label="name"
              multiple
              :close-on-select="false"
              :clear-on-select="false"
              hide-selected
              selected-label
              :select-label="t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
              :deselect-label="t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
              :placeholder="t('INBOX_MGMT.ADD.TEAMS.PICK_TEAMS')"
            />
            <span v-if="hasError" class="message">
              {{ t('INBOX_MGMT.ADD.TEAMS.VALIDATION_ERROR') }}
            </span>
          </label>
        </div>
        <div class="w-full">
          <NextButton
            type="submit"
            :is-loading="isCreating"
            solid
            blue
            :label="t('INBOX_MGMT.AGENTS.BUTTON_TEXT')"
          />
        </div>
      </div>
    </form>
  </div>
</template>
