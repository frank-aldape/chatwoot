<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Avatar from 'next/avatar/Avatar.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  useMapGetter,
  useStoreGetters,
  useStore,
} from 'dashboard/composables/store';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();
const { isAdmin } = useAdmin();

const showDeletePopup = ref(false);
const selectedInbox = ref({});
const selectedManagedCompanyId = ref('all');
const searchQuery = ref('');
const expandedGroupIds = ref(new Set());

const inboxes = useMapGetter('inboxes/getInboxes');

const managedCompanyOptions = computed(() => {
  const companies = (inboxes.value || [])
    .map(inbox => inbox.managed_company)
    .filter(Boolean)
    .reduce((acc, company) => {
      acc.set(company.id, company);
      return acc;
    }, new Map());

  return Array.from(companies.values()).sort((a, b) =>
    a.name.localeCompare(b.name)
  );
});

const companyFilterOptions = computed(() => [
  { id: 'all', name: t('INBOX_MGMT.FILTER.ALL_MANAGED_COMPANIES') },
  { id: 'unassigned', name: t('INBOX_MGMT.FILTER.UNASSIGNED') },
  ...managedCompanyOptions.value,
]);

const selectedCompanyFilter = computed({
  get: () =>
    companyFilterOptions.value.find(
      o => String(o.id) === selectedManagedCompanyId.value
    ) ?? companyFilterOptions.value[0],
  set: value => {
    selectedManagedCompanyId.value = value ? String(value.id) : 'all';
  },
});

const matchesManagedCompanyFilter = inbox => {
  if (selectedManagedCompanyId.value === 'all') return true;
  if (selectedManagedCompanyId.value === 'unassigned') {
    return !inbox.managed_company;
  }

  return (
    String(inbox.managed_company?.id || '') === selectedManagedCompanyId.value
  );
};

const getInboxChannelLabel = inbox => {
  const labels = {
    'Channel::FacebookPage': t('INBOX_MGMT.CHANNELS.MESSENGER'),
    'Channel::WebWidget': t('INBOX_MGMT.CHANNELS.WEB_WIDGET'),
    'Channel::TwitterProfile': t('INBOX_MGMT.CHANNELS.TWITTER_PROFILE'),
    'Channel::Whatsapp': t('INBOX_MGMT.CHANNELS.WHATSAPP'),
    'Channel::Sms': t('INBOX_MGMT.CHANNELS.SMS'),
    'Channel::Email': t('INBOX_MGMT.CHANNELS.EMAIL'),
    'Channel::Telegram': t('INBOX_MGMT.CHANNELS.TELEGRAM'),
    'Channel::Line': t('INBOX_MGMT.CHANNELS.LINE'),
    'Channel::Api': t('INBOX_MGMT.CHANNELS.API'),
    'Channel::Instagram': t('INBOX_MGMT.CHANNELS.INSTAGRAM'),
    'Channel::Tiktok': t('INBOX_MGMT.CHANNELS.TIKTOK'),
    'Channel::Voice': t('INBOX_MGMT.CHANNELS.VOICE'),
  };

  if (inbox.channel_type === 'Channel::TwilioSms') {
    return inbox.medium === 'whatsapp'
      ? t('INBOX_MGMT.CHANNELS.WHATSAPP')
      : t('INBOX_MGMT.CHANNELS.TWILIO_SMS');
  }

  return labels[inbox.channel_type] || inbox.channel_type;
};

const getInboxSourceLabel = inbox => {
  return (
    inbox.email ||
    inbox.phone_number ||
    inbox.website_url ||
    inbox.forward_to_email ||
    inbox.business_name ||
    ''
  );
};

const getInboxSubtitle = inbox => {
  return [getInboxChannelLabel(inbox), getInboxSourceLabel(inbox)]
    .filter(Boolean)
    .join(' - ');
};

const getInboxSearchFields = inbox => {
  return [
    inbox.name,
    getInboxChannelLabel(inbox),
    getInboxSourceLabel(inbox),
    inbox.email,
    inbox.phone_number,
    inbox.forward_to_email,
    inbox.business_name,
    inbox.channel_type,
    inbox.provider,
    inbox.website_url,
    inbox.managed_company?.name,
    inbox.managed_company?.authorized_domain,
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();
};

const inboxesList = computed(() => {
  const normalizedSearch = searchQuery.value.trim().toLowerCase();
  const sortedInboxes = inboxes.value
    ?.slice()
    .sort((a, b) => {
      const companyCompare = (a.managed_company?.name || '').localeCompare(
        b.managed_company?.name || ''
      );
      if (companyCompare !== 0) return companyCompare;

      const channelCompare = getInboxChannelLabel(a).localeCompare(
        getInboxChannelLabel(b)
      );
      if (channelCompare !== 0) return channelCompare;

      return a.name.localeCompare(b.name);
    })
    .filter(matchesManagedCompanyFilter);

  if (!normalizedSearch) {
    return sortedInboxes;
  }

  return sortedInboxes.filter(inbox =>
    getInboxSearchFields(inbox).includes(normalizedSearch)
  );
});

const groupedInboxesList = computed(() => {
  const groups = inboxesList.value.reduce((acc, inbox) => {
    const company = inbox.managed_company;
    const key = company?.id ? String(company.id) : 'unassigned';

    if (!acc[key]) {
      acc[key] = {
        id: key,
        name: company?.name || t('INBOX_MGMT.GROUPS.UNASSIGNED_TITLE'),
        authorizedDomain:
          company?.authorized_domain ||
          t('INBOX_MGMT.GROUPS.UNASSIGNED_SUBTITLE'),
        inboxes: [],
      };
    }

    acc[key].inboxes.push(inbox);
    return acc;
  }, {});

  return Object.values(groups)
    .map(group => ({
      ...group,
      inboxes: group.inboxes.sort((a, b) => {
        const channelCompare = getInboxChannelLabel(a).localeCompare(
          getInboxChannelLabel(b)
        );
        if (channelCompare !== 0) return channelCompare;
        return a.name.localeCompare(b.name);
      }),
    }))
    .sort((a, b) => a.name.localeCompare(b.name));
});

const hasActiveSearch = computed(() => searchQuery.value.trim().length > 0);
const isFiltered = computed(
  () => hasActiveSearch.value || selectedManagedCompanyId.value !== 'all'
);
const isGroupExpanded = groupId =>
  isFiltered.value || expandedGroupIds.value.has(groupId);
const toggleGroup = groupId => {
  const next = new Set(expandedGroupIds.value);
  if (next.has(groupId)) {
    next.delete(groupId);
  } else {
    next.add(groupId);
  }
  expandedGroupIds.value = next;
};
const hasRecords = computed(() => (inboxes.value || []).length > 0);
const showNoRecordsFound = computed(
  () => !hasRecords.value && !hasActiveSearch.value
);
const showEmptySearchResults = computed(
  () => hasRecords.value && (inboxesList.value || []).length === 0
);

const uiFlags = computed(() => getters['inboxes/getUIFlags'].value);

const deleteConfirmText = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.YES')} ${selectedInbox.value.name}`
);

const deleteRejectText = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.NO')} ${selectedInbox.value.name}`
);

const confirmDeleteMessage = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.MESSAGE')} ${selectedInbox.value.name}?`
);
const confirmPlaceHolderText = computed(
  () =>
    `${t('INBOX_MGMT.DELETE.CONFIRM.PLACE_HOLDER', {
      inboxName: selectedInbox.value.name,
    })}`
);

const deleteInbox = async ({ id }) => {
  try {
    await store.dispatch('inboxes/delete', id);
    useAlert(t('INBOX_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.DELETE.API.ERROR_MESSAGE'));
  }
};
const closeDelete = () => {
  showDeletePopup.value = false;
  selectedInbox.value = {};
};

const confirmDeletion = () => {
  deleteInbox(selectedInbox.value);
  closeDelete();
};
const openDelete = inbox => {
  showDeletePopup.value = true;
  selectedInbox.value = inbox;
};
</script>

<template>
  <SettingsLayout
    :no-records-found="showNoRecordsFound"
    :no-records-message="$t('INBOX_MGMT.LIST.404')"
    :is-loading="uiFlags.isFetching"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('INBOX_MGMT.HEADER')"
        :description="$t('INBOX_MGMT.DESCRIPTION')"
        :link-text="$t('INBOX_MGMT.LEARN_MORE')"
        feature-name="inboxes"
      >
        <template #actions>
          <router-link v-if="isAdmin" :to="{ name: 'settings_inbox_new' }">
            <Button
              icon="i-lucide-circle-plus"
              :label="$t('SETTINGS.INBOXES.NEW_INBOX')"
            />
          </router-link>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #preBody>
      <div class="mb-4 flex flex-col gap-3 lg:flex-row lg:items-center">
        <Input
          v-model="searchQuery"
          type="search"
          :aria-label="$t('INBOX_MGMT.SEARCH.PLACEHOLDER')"
          :placeholder="$t('INBOX_MGMT.SEARCH.PLACEHOLDER')"
          class="max-w-md"
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
        <div class="grid gap-1 text-sm text-n-slate-11 lg:min-w-64">
          <span class="font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.FILTER.MANAGED_COMPANY_LABEL') }}
          </span>
          <multiselect
            v-model="selectedCompanyFilter"
            :options="companyFilterOptions"
            track-by="id"
            label="name"
            :allow-empty="false"
            :show-labels="false"
            :placeholder="$t('INBOX_MGMT.FILTER.ALL_MANAGED_COMPANIES')"
          />
        </div>
      </div>
    </template>
    <template #body>
      <p
        v-if="showEmptySearchResults"
        class="flex items-center justify-center py-16 text-base text-n-slate-11"
      >
        {{ $t('INBOX_MGMT.SEARCH.NO_RESULTS') }}
      </p>
      <div v-else class="grid gap-4">
        <section
          v-for="group in groupedInboxesList"
          :key="group.id"
          class="overflow-hidden rounded-xl border border-n-weak bg-n-background"
        >
          <button
            type="button"
            class="flex w-full flex-col gap-1 border-b border-n-weak bg-n-alpha-1 px-4 py-3 text-left lg:flex-row lg:items-center lg:justify-between"
            :aria-expanded="isGroupExpanded(group.id)"
            @click="toggleGroup(group.id)"
          >
            <div class="flex items-center gap-2">
              <Icon
                icon="i-lucide-chevron-right"
                class="size-4 shrink-0 text-n-slate-11 transition-transform"
                :class="{ 'rotate-90': isGroupExpanded(group.id) }"
              />
              <div>
                <h3 class="text-sm font-semibold text-n-slate-12">
                  {{ group.name }}
                </h3>
                <p class="text-sm text-n-slate-11">
                  {{ group.authorizedDomain }}
                </p>
              </div>
            </div>
            <span
              class="text-xs font-medium uppercase tracking-wide text-n-slate-11"
            >
              {{
                $t('INBOX_MGMT.GROUPS.INBOX_COUNT', {
                  count: group.inboxes.length,
                })
              }}
            </span>
          </button>

          <table
            v-if="isGroupExpanded(group.id)"
            class="min-w-full overflow-x-auto"
          >
            <tbody class="divide-y divide-n-weak flex-1 text-n-slate-12">
              <tr v-for="inbox in group.inboxes" :key="inbox.id">
                <td class="py-4 ltr:pr-4 rtl:pl-4">
                  <div class="flex items-center flex-row gap-4 px-4">
                    <div
                      v-if="inbox.avatar_url"
                      class="bg-n-alpha-3 rounded-full size-12 p-2 ring ring-n-solid-1 border border-n-strong shadow-sm"
                    >
                      <Avatar
                        :src="inbox.avatar_url"
                        :name="inbox.name"
                        :size="30"
                        rounded-full
                      />
                    </div>
                    <div
                      v-else
                      class="size-12 flex justify-center items-center bg-n-alpha-3 rounded-full p-2 ring ring-n-solid-1 border border-n-strong shadow-sm"
                    >
                      <ChannelIcon
                        class="size-5 text-n-slate-10"
                        :inbox="inbox"
                      />
                    </div>
                    <div class="min-w-0">
                      <span class="block font-medium capitalize">
                        {{ inbox.name }}
                      </span>
                      <span class="block truncate text-sm text-n-slate-11">
                        {{ getInboxSubtitle(inbox) }}
                      </span>
                      <span
                        v-if="inbox.managed_company?.authorized_domain"
                        class="block truncate text-xs text-n-slate-10"
                      >
                        {{ inbox.managed_company.authorized_domain }}
                      </span>
                    </div>
                  </div>
                </td>
                <td class="py-4 px-4">
                  <div class="flex gap-1 justify-end">
                    <router-link
                      :to="{
                        name: 'settings_inbox_show',
                        params: { inboxId: inbox.id },
                      }"
                    >
                      <Button
                        v-if="isAdmin"
                        v-tooltip.top="$t('INBOX_MGMT.SETTINGS')"
                        :aria-label="$t('INBOX_MGMT.SETTINGS')"
                        icon="i-lucide-settings"
                        slate
                        xs
                        faded
                      />
                    </router-link>
                    <Button
                      v-if="isAdmin"
                      v-tooltip.top="$t('INBOX_MGMT.DELETE.BUTTON_TEXT')"
                      :aria-label="$t('INBOX_MGMT.DELETE.BUTTON_TEXT')"
                      icon="i-lucide-trash-2"
                      xs
                      ruby
                      faded
                      @click="openDelete(inbox)"
                    />
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </section>
      </div>
    </template>

    <woot-confirm-delete-modal
      v-if="showDeletePopup"
      v-model:show="showDeletePopup"
      :title="$t('INBOX_MGMT.DELETE.CONFIRM.TITLE')"
      :message="confirmDeleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
      :confirm-value="selectedInbox.name"
      :confirm-place-holder-text="confirmPlaceHolderText"
      @on-confirm="confirmDeletion"
      @on-close="closeDelete"
    />
  </SettingsLayout>
</template>
