<script setup>
import { computed, onMounted, ref, watch } from 'vue';

import { useAlert } from 'dashboard/composables';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { LocalStorage } from 'shared/helpers/localStorage';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import ManagedCompaniesAPI from 'dashboard/api/managedCompanies';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import ManagedCompanyFormModal from './ManagedCompanyFormModal.vue';
import ManagedCompanyDetailsModal from './ManagedCompanyDetailsModal.vue';

const { t } = useI18n();
const store = useStore();

const managedCompanies = ref([]);
const isLoading = ref(false);
const isSubmitting = ref(false);
const searchQuery = ref('');
const statusFilter = ref('all');
const sortBy = ref('name');
const sortOrder = ref('asc');
const currentPage = ref(1);
const showDeletePopup = ref(false);
const showFormModal = ref(false);
const showDetailsModal = ref(false);
const selectedManagedCompany = ref({});

const restorePreferences = () => {
  const storedPreferences =
    LocalStorage.get(LOCAL_STORAGE_KEYS.MANAGED_COMPANIES_PREFERENCES) || {};

  if (storedPreferences.statusFilter) {
    statusFilter.value = storedPreferences.statusFilter;
  }

  if (storedPreferences.sortBy) {
    sortBy.value = storedPreferences.sortBy;
  }

  if (storedPreferences.sortOrder) {
    sortOrder.value = storedPreferences.sortOrder;
  }
};

const persistPreferences = () => {
  LocalStorage.set(LOCAL_STORAGE_KEYS.MANAGED_COMPANIES_PREFERENCES, {
    statusFilter: statusFilter.value,
    sortBy: sortBy.value,
    sortOrder: sortOrder.value,
  });
};

const inboxes = useMapGetter('inboxes/getInboxes');
const teams = useMapGetter('teams/getTeams');

const teamNamesById = computed(() =>
  (teams.value || []).reduce((acc, team) => {
    acc[team.id] = team.name;
    return acc;
  }, {})
);

const inboxNamesById = computed(() =>
  (inboxes.value || []).reduce((acc, inbox) => {
    acc[inbox.id] = inbox.name;
    return acc;
  }, {})
);

const statusLabel = status => {
  switch (status) {
    case 'inactive':
      return t('MANAGED_COMPANIES_SETTINGS.LIST.STATUS_INACTIVE');
    case 'active':
    default:
      return t('MANAGED_COMPANIES_SETTINGS.LIST.STATUS_ACTIVE');
  }
};

const resolvedManagedCompanies = computed(() =>
  managedCompanies.value.map(managedCompany => ({
    ...managedCompany,
    inboxNames: (managedCompany.inbox_ids || [])
      .map(id => inboxNamesById.value[id])
      .filter(Boolean),
    teamNames: (managedCompany.team_ids || [])
      .map(id => teamNamesById.value[id])
      .filter(Boolean),
  }))
);

const normalizedSearchQuery = computed(() =>
  searchQuery.value.trim().toLowerCase()
);
const hasActiveSearch = computed(() => normalizedSearchQuery.value.length > 0);

const filteredManagedCompanies = computed(() => {
  const filteredBySearch = resolvedManagedCompanies.value.filter(
    ({ name, authorized_domain: authorizedDomain, status }) => {
      const matchesSearch =
        !normalizedSearchQuery.value ||
        [name, authorizedDomain]
          .filter(Boolean)
          .join(' ')
          .toLowerCase()
          .includes(normalizedSearchQuery.value);

      const matchesStatus =
        statusFilter.value === 'all' || status === statusFilter.value;

      return matchesSearch && matchesStatus;
    }
  );

  return [...filteredBySearch].sort((left, right) => {
    const direction = sortOrder.value === 'asc' ? 1 : -1;

    if (sortBy.value === 'status') {
      return left.status.localeCompare(right.status) * direction;
    }

    return left.name.localeCompare(right.name) * direction;
  });
});

const ITEMS_PER_PAGE = 10;

const paginatedManagedCompanies = computed(() => {
  const startIndex = (currentPage.value - 1) * ITEMS_PER_PAGE;
  return filteredManagedCompanies.value.slice(
    startIndex,
    startIndex + ITEMS_PER_PAGE
  );
});

const toggleSort = field => {
  if (sortBy.value === field) {
    sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc';
    return;
  }

  sortBy.value = field;
  sortOrder.value = 'asc';
};

const sortIcon = field => {
  if (sortBy.value !== field) {
    return 'i-lucide-arrow-up-down';
  }

  return sortOrder.value === 'asc'
    ? 'i-lucide-arrow-up-az'
    : 'i-lucide-arrow-down-az';
};

const filterOptions = computed(() => [
  {
    value: 'all',
    label: t('MANAGED_COMPANIES_SETTINGS.FILTER.ALL'),
  },
  {
    value: 'active',
    label: t('MANAGED_COMPANIES_SETTINGS.FILTER.ACTIVE'),
  },
  {
    value: 'inactive',
    label: t('MANAGED_COMPANIES_SETTINGS.FILTER.INACTIVE'),
  },
]);

const selectedStatusFilter = computed({
  get: () =>
    filterOptions.value.find(o => o.value === statusFilter.value) ??
    filterOptions.value[0],
  set: value => {
    statusFilter.value = value?.value ?? 'all';
  },
});

const showEmptySearchResults = computed(() => {
  if (!hasActiveSearch.value && statusFilter.value === 'all') {
    return false;
  }

  return filteredManagedCompanies.value.length === 0;
});

const emptySearchMessage = computed(() => {
  if (hasActiveSearch.value && statusFilter.value !== 'all') {
    return t('MANAGED_COMPANIES_SETTINGS.SEARCH.NO_RESULTS_WITH_FILTER');
  }

  if (hasActiveSearch.value) {
    return t('MANAGED_COMPANIES_SETTINGS.SEARCH.NO_RESULTS');
  }

  return t('MANAGED_COMPANIES_SETTINGS.FILTER.NO_RESULTS');
});

const hasRecords = computed(() => resolvedManagedCompanies.value.length > 0);
const showNoRecordsFound = computed(
  () => !hasRecords.value && !hasActiveSearch.value
);

const resetSelection = () => {
  selectedManagedCompany.value = {};
};

const fetchManagedCompanies = async () => {
  isLoading.value = true;
  try {
    const response = await ManagedCompaniesAPI.get();
    managedCompanies.value = response.data || [];
  } catch (error) {
    useAlert(t('MANAGED_COMPANIES_SETTINGS.API.LIST_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const closeFormModal = () => {
  showFormModal.value = false;
  resetSelection();
};

const openCreateModal = () => {
  resetSelection();
  showFormModal.value = true;
};

const openEditModal = managedCompany => {
  selectedManagedCompany.value = managedCompany;
  showFormModal.value = true;
};

const openDetailsModal = managedCompany => {
  selectedManagedCompany.value = managedCompany;
  showDetailsModal.value = true;
};

const submitForm = async formData => {
  isSubmitting.value = true;

  const payload = {
    managed_company: {
      name: formData.name,
      authorized_domain: formData.authorizedDomain,
      status: formData.status,
    },
  };

  try {
    if (selectedManagedCompany.value.id) {
      await ManagedCompaniesAPI.update(
        selectedManagedCompany.value.id,
        payload
      );
      useAlert(t('MANAGED_COMPANIES_SETTINGS.API.UPDATE_SUCCESS'));
    } else {
      await ManagedCompaniesAPI.create(payload);
      useAlert(t('MANAGED_COMPANIES_SETTINGS.API.CREATE_SUCCESS'));
    }

    closeFormModal();
    fetchManagedCompanies();
  } catch (error) {
    useAlert(
      selectedManagedCompany.value.id
        ? t('MANAGED_COMPANIES_SETTINGS.API.UPDATE_ERROR')
        : t('MANAGED_COMPANIES_SETTINGS.API.CREATE_ERROR')
    );
  } finally {
    isSubmitting.value = false;
  }
};

const openDelete = managedCompany => {
  selectedManagedCompany.value = managedCompany;
  showDeletePopup.value = true;
};

const closeDetailsModal = () => {
  showDetailsModal.value = false;
  resetSelection();
};

const closeDelete = () => {
  showDeletePopup.value = false;
  resetSelection();
};

const confirmDeletion = async () => {
  try {
    await ManagedCompaniesAPI.delete(selectedManagedCompany.value.id);
    useAlert(t('MANAGED_COMPANIES_SETTINGS.API.DELETE_SUCCESS'));
    fetchManagedCompanies();
  } catch (error) {
    useAlert(t('MANAGED_COMPANIES_SETTINGS.API.DELETE_ERROR'));
  } finally {
    closeDelete();
  }
};

onMounted(() => {
  restorePreferences();
  fetchManagedCompanies();
  store.dispatch('inboxes/get');
  store.dispatch('teams/get');
});

watch([statusFilter, sortBy, sortOrder], persistPreferences);
watch([searchQuery, statusFilter], () => {
  currentPage.value = 1;
});
watch(filteredManagedCompanies, companies => {
  const totalPages = Math.max(1, Math.ceil(companies.length / ITEMS_PER_PAGE));
  if (currentPage.value > totalPages) {
    currentPage.value = totalPages;
  }
});
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('MANAGED_COMPANIES_SETTINGS.LOADING')"
    :no-records-found="showNoRecordsFound"
    :no-records-message="$t('MANAGED_COMPANIES_SETTINGS.EMPTY')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('MANAGED_COMPANIES_SETTINGS.HEADER')"
        :description="$t('MANAGED_COMPANIES_SETTINGS.DESCRIPTION')"
      >
        <template #actions>
          <Button
            icon="i-lucide-circle-plus"
            :label="$t('MANAGED_COMPANIES_SETTINGS.HEADER_BUTTON')"
            @click="openCreateModal"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #preBody>
      <div class="mb-4 flex flex-col gap-3 lg:flex-row lg:items-center">
        <div class="max-w-md flex-1">
          <Input
            v-model="searchQuery"
            type="search"
            :placeholder="$t('MANAGED_COMPANIES_SETTINGS.SEARCH.PLACEHOLDER')"
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

        <div class="flex items-center gap-2">
          <span class="text-sm text-n-slate-11">
            {{ $t('MANAGED_COMPANIES_SETTINGS.FILTER.LABEL') }}
          </span>
          <multiselect
            v-model="selectedStatusFilter"
            :options="filterOptions"
            track-by="value"
            label="label"
            :allow-empty="false"
            :searchable="false"
            :show-labels="false"
            class="min-w-40"
          />
        </div>
      </div>
    </template>

    <template #body>
      <p
        v-if="showEmptySearchResults"
        class="flex items-center justify-center py-16 text-base text-n-slate-11"
      >
        {{ emptySearchMessage }}
      </p>
      <div v-else class="grid gap-4">
        <table class="min-w-full divide-y divide-n-weak">
          <thead>
            <tr class="text-left text-sm font-medium text-n-slate-11">
              <th class="py-4 ltr:pr-4 rtl:pl-4">
                <button
                  class="flex items-center gap-2 p-0 text-left font-medium text-n-slate-11"
                  @click="toggleSort('name')"
                >
                  <span>
                    {{ $t('MANAGED_COMPANIES_SETTINGS.TABLE.COMPANY') }}
                  </span>
                  <Icon :icon="sortIcon('name')" class="size-4" />
                </button>
              </th>
              <th class="py-4 ltr:pr-4 rtl:pl-4">
                <button
                  class="flex items-center gap-2 p-0 text-left font-medium text-n-slate-11"
                  @click="toggleSort('status')"
                >
                  <span>
                    {{ $t('MANAGED_COMPANIES_SETTINGS.TABLE.STATUS') }}
                  </span>
                  <Icon :icon="sortIcon('status')" class="size-4" />
                </button>
              </th>
              <th class="py-4 ltr:pr-4 rtl:pl-4">
                {{ $t('MANAGED_COMPANIES_SETTINGS.TABLE.INBOXES') }}
              </th>
              <th class="py-4 ltr:pr-4 rtl:pl-4">
                {{ $t('MANAGED_COMPANIES_SETTINGS.TABLE.TEAMS') }}
              </th>
              <th class="py-4 text-right">
                {{ $t('MANAGED_COMPANIES_SETTINGS.TABLE.ACTIONS') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak text-n-slate-11">
            <tr
              v-for="managedCompany in paginatedManagedCompanies"
              :key="managedCompany.id"
            >
              <td class="py-4 ltr:pr-4 rtl:pl-4">
                <div class="flex flex-col gap-1">
                  <span class="font-medium text-n-slate-12">
                    {{ managedCompany.name }}
                  </span>
                  <span>{{ managedCompany.authorized_domain }}</span>
                </div>
              </td>
              <td class="py-4 ltr:pr-4 rtl:pl-4">
                <span
                  class="inline-flex rounded-full bg-n-alpha-2 px-2.5 py-1 text-xs font-medium text-n-slate-12"
                >
                  {{ statusLabel(managedCompany.status) }}
                </span>
              </td>
              <td class="py-4 ltr:pr-4 rtl:pl-4">
                <span class="text-sm">
                  {{
                    $t('MANAGED_COMPANIES_SETTINGS.LIST.INBOX_COUNT', {
                      count: managedCompany.inbox_ids.length,
                    })
                  }}
                </span>
              </td>
              <td class="py-4 ltr:pr-4 rtl:pl-4">
                <span class="text-sm">
                  {{
                    $t('MANAGED_COMPANIES_SETTINGS.LIST.TEAM_COUNT', {
                      count: managedCompany.team_ids.length,
                    })
                  }}
                </span>
              </td>
              <td class="py-4">
                <div class="flex justify-end gap-1">
                  <Button
                    v-tooltip.top="$t('MANAGED_COMPANIES_SETTINGS.LIST.VIEW')"
                    icon="i-lucide-eye"
                    slate
                    xs
                    faded
                    @click="openDetailsModal(managedCompany)"
                  />
                  <Button
                    v-tooltip.top="$t('MANAGED_COMPANIES_SETTINGS.LIST.EDIT')"
                    icon="i-lucide-pen"
                    slate
                    xs
                    faded
                    @click="openEditModal(managedCompany)"
                  />
                  <Button
                    v-tooltip.top="$t('MANAGED_COMPANIES_SETTINGS.LIST.DELETE')"
                    icon="i-lucide-trash-2"
                    xs
                    ruby
                    faded
                    @click="openDelete(managedCompany)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <PaginationFooter
          v-if="filteredManagedCompanies.length > ITEMS_PER_PAGE"
          v-model:current-page="currentPage"
          :total-items="filteredManagedCompanies.length"
          :items-per-page="ITEMS_PER_PAGE"
        />
      </div>
    </template>

    <ManagedCompanyFormModal
      :show="showFormModal"
      :is-editing="Boolean(selectedManagedCompany.id)"
      :is-submitting="isSubmitting"
      :managed-company="selectedManagedCompany"
      @close="closeFormModal"
      @submit="submitForm"
    />

    <ManagedCompanyDetailsModal
      :show="showDetailsModal"
      :managed-company="selectedManagedCompany"
      @close="closeDetailsModal"
    />

    <woot-confirm-delete-modal
      v-if="showDeletePopup"
      v-model:show="showDeletePopup"
      :title="$t('MANAGED_COMPANIES_SETTINGS.DELETE.TITLE')"
      :message="$t('MANAGED_COMPANIES_SETTINGS.DELETE.MESSAGE')"
      :confirm-text="$t('MANAGED_COMPANIES_SETTINGS.DELETE.CONFIRM')"
      :reject-text="$t('MANAGED_COMPANIES_SETTINGS.DELETE.CANCEL')"
      :confirm-value="selectedManagedCompany.name"
      :confirm-place-holder-text="
        $t('MANAGED_COMPANIES_SETTINGS.DELETE.PLACEHOLDER', {
          name: selectedManagedCompany.name,
        })
      "
      @on-confirm="confirmDeletion"
      @on-close="closeDelete"
    />
  </SettingsLayout>
</template>
