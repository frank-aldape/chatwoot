<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import TeamsAPI from 'dashboard/api/teams';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const { t } = useI18n();
const store = useStore();

const isLoading = ref(false);
const isSubmitting = ref(false);
const searchQuery = ref('');
const currentPage = ref(1);
const selectedInboxIds = ref(new Set());
const targetTeamId = ref(null);

const inboxes = useMapGetter('inboxes/getInboxes');
const teams = useMapGetter('teams/getTeams');

// Each team already returns `managed_company_assignments`, the exact shape
// the bulk-assign endpoint expects back — see _team.json.jbuilder.
const teamNamesByInboxId = computed(() => {
  const map = {};
  (teams.value || []).forEach(team => {
    (team.managed_company_assignments || []).forEach(assignment => {
      assignment.inbox_ids.forEach(inboxId => {
        if (!map[inboxId]) map[inboxId] = [];
        map[inboxId].push(team.name);
      });
    });
  });
  return map;
});

const rows = computed(() =>
  (inboxes.value || []).map(inbox => ({
    id: inbox.id,
    name: inbox.name,
    channelType: inbox.channel_type,
    managedCompany: inbox.managed_company || null,
    teamNames: teamNamesByInboxId.value[inbox.id] || [],
  }))
);

const normalizedSearchQuery = computed(() =>
  searchQuery.value.trim().toLowerCase()
);

const filteredRows = computed(() => {
  const query = normalizedSearchQuery.value;
  if (!query) return rows.value;

  return rows.value.filter(row =>
    [row.name, row.managedCompany?.name]
      .filter(Boolean)
      .join(' ')
      .toLowerCase()
      .includes(query)
  );
});

const ITEMS_PER_PAGE = 15;

const paginatedRows = computed(() => {
  const startIndex = (currentPage.value - 1) * ITEMS_PER_PAGE;
  return filteredRows.value.slice(startIndex, startIndex + ITEMS_PER_PAGE);
});

const selectedCount = computed(() => selectedInboxIds.value.size);

const isRowSelected = inboxId => selectedInboxIds.value.has(inboxId);

const toggleRow = inboxId => {
  const next = new Set(selectedInboxIds.value);
  if (next.has(inboxId)) {
    next.delete(inboxId);
  } else {
    next.add(inboxId);
  }
  selectedInboxIds.value = next;
};

const isPageFullySelected = computed(
  () =>
    paginatedRows.value.length > 0 &&
    paginatedRows.value.every(row => isRowSelected(row.id))
);

const togglePageSelection = () => {
  const next = new Set(selectedInboxIds.value);
  if (isPageFullySelected.value) {
    paginatedRows.value.forEach(row => next.delete(row.id));
  } else {
    paginatedRows.value.forEach(row => next.add(row.id));
  }
  selectedInboxIds.value = next;
};

const clearSelection = () => {
  selectedInboxIds.value = new Set();
};

const teamOptions = computed(() => teams.value || []);

const fetchData = async () => {
  isLoading.value = true;
  try {
    await Promise.all([
      store.dispatch('inboxes/get'),
      store.dispatch('teams/get'),
    ]);
  } finally {
    isLoading.value = false;
  }
};

const assignSelectionToTeam = async () => {
  if (!targetTeamId.value || selectedInboxIds.value.size === 0) return;

  const team = teamOptions.value.find(
    candidate => candidate.id === targetTeamId.value
  );
  if (!team) return;

  const selectedInboxes = (inboxes.value || []).filter(inbox =>
    selectedInboxIds.value.has(inbox.id)
  );

  const skippedWithoutCompany = selectedInboxes.filter(
    inbox => !inbox.managed_company
  );
  if (skippedWithoutCompany.length) {
    useAlert(t('INBOX_ASSIGNMENT.NO_COMPANY_WARNING'));
  }

  // Merge with what the team already has per company so we don't drop
  // existing inbox assignments — Teams::ManagedCompanyAssignmentsService
  // replaces the full inbox set per managed_company_id on every call.
  const byCompany = new Map(
    (team.managed_company_assignments || []).map(assignment => [
      assignment.managed_company_id,
      {
        inboxIds: new Set(assignment.inbox_ids),
        channelKeys: assignment.channel_keys,
      },
    ])
  );

  selectedInboxes.forEach(inbox => {
    if (!inbox.managed_company) return;

    const companyId = inbox.managed_company.id;
    const existing = byCompany.get(companyId) || {
      inboxIds: new Set(),
      channelKeys: [],
    };
    existing.inboxIds.add(inbox.id);
    byCompany.set(companyId, existing);
  });

  const managedCompanyAssignments = [...byCompany.entries()].map(
    ([managedCompanyId, value]) => ({
      managed_company_id: managedCompanyId,
      inbox_ids: [...value.inboxIds],
      channel_keys: value.channelKeys,
    })
  );

  isSubmitting.value = true;
  try {
    await TeamsAPI.update(team.id, {
      managed_company_assignments: managedCompanyAssignments,
    });
    useAlert(t('INBOX_ASSIGNMENT.ASSIGN_SUCCESS', { team: team.name }));
    clearSelection();
    targetTeamId.value = null;
    await store.dispatch('teams/get');
  } catch (error) {
    useAlert(t('INBOX_ASSIGNMENT.ASSIGN_ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};

const showNoRecordsFound = computed(
  () => !isLoading.value && filteredRows.value.length === 0
);

onMounted(fetchData);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="t('INBOX_ASSIGNMENT.LOADING')"
    :no-records-found="showNoRecordsFound"
    :no-records-message="t('INBOX_ASSIGNMENT.EMPTY')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('INBOX_ASSIGNMENT.HEADER')"
        :description="t('INBOX_ASSIGNMENT.DESCRIPTION')"
      />
    </template>

    <template #preBody>
      <div class="mb-4 flex flex-col gap-3 lg:flex-row lg:items-center">
        <div class="max-w-md flex-1">
          <Input
            v-model="searchQuery"
            type="search"
            :aria-label="t('INBOX_ASSIGNMENT.SEARCH_PLACEHOLDER')"
            :placeholder="t('INBOX_ASSIGNMENT.SEARCH_PLACEHOLDER')"
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

        <div
          v-if="selectedCount > 0"
          class="flex items-center gap-2 rounded-lg bg-n-alpha-2 px-3 py-2"
        >
          <span class="text-sm text-n-slate-12 whitespace-nowrap">
            {{ t('INBOX_ASSIGNMENT.SELECTED_COUNT', { count: selectedCount }) }}
          </span>
          <multiselect
            v-model="targetTeamId"
            :options="teamOptions.map(team => team.id)"
            :custom-label="id => teamOptions.find(team => team.id === id)?.name"
            :placeholder="t('INBOX_ASSIGNMENT.TEAM_PLACEHOLDER')"
            allow-empty
            :show-labels="false"
            class="min-w-48"
          />
          <Button
            :label="t('INBOX_ASSIGNMENT.ASSIGN_BUTTON')"
            size="sm"
            :is-loading="isSubmitting"
            :disabled="!targetTeamId"
            @click="assignSelectionToTeam"
          />
          <Button
            :label="t('INBOX_ASSIGNMENT.CLEAR_SELECTION')"
            variant="ghost"
            color="slate"
            size="sm"
            @click="clearSelection"
          />
        </div>
      </div>
    </template>

    <template #body>
      <div class="grid gap-4">
        <table class="min-w-full divide-y divide-n-weak">
          <thead>
            <tr class="text-left text-sm font-medium text-n-slate-11">
              <th class="py-4 ltr:pr-4 rtl:pl-4 w-10">
                <input
                  type="checkbox"
                  :checked="isPageFullySelected"
                  :aria-label="t('INBOX_ASSIGNMENT.SELECT_ALL')"
                  @change="togglePageSelection"
                />
              </th>
              <th class="py-4 ltr:pr-4 rtl:pl-4">
                {{ t('INBOX_ASSIGNMENT.TABLE.INBOX') }}
              </th>
              <th class="py-4 ltr:pr-4 rtl:pl-4">
                {{ t('INBOX_ASSIGNMENT.TABLE.COMPANY') }}
              </th>
              <th class="py-4 ltr:pr-4 rtl:pl-4">
                {{ t('INBOX_ASSIGNMENT.TABLE.TEAMS') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak text-n-slate-11">
            <tr v-for="row in paginatedRows" :key="row.id">
              <td class="py-4 ltr:pr-4 rtl:pl-4">
                <input
                  type="checkbox"
                  :checked="isRowSelected(row.id)"
                  :aria-label="row.name"
                  @change="toggleRow(row.id)"
                />
              </td>
              <td class="py-4 ltr:pr-4 rtl:pl-4">
                <span class="font-medium text-n-slate-12">
                  {{ row.name }}
                </span>
              </td>
              <td class="py-4 ltr:pr-4 rtl:pl-4">
                <span
                  v-if="row.managedCompany"
                  class="inline-flex rounded-full bg-n-alpha-2 px-2.5 py-1 text-xs font-medium text-n-slate-12"
                >
                  {{ row.managedCompany.name }}
                </span>
                <span v-else class="text-xs text-n-slate-10">
                  {{ t('INBOX_ASSIGNMENT.TABLE.NO_COMPANY') }}
                </span>
              </td>
              <td class="py-4 ltr:pr-4 rtl:pl-4">
                <span class="text-sm">
                  {{ row.teamNames.join(', ') || '—' }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>

        <PaginationFooter
          v-if="filteredRows.length > ITEMS_PER_PAGE"
          v-model:current-page="currentPage"
          :total-items="filteredRows.length"
          :items-per-page="ITEMS_PER_PAGE"
        />
      </div>
    </template>
  </SettingsLayout>
</template>
