<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import { generateLabelForContactableInboxesList } from 'dashboard/components-next/NewConversation/helpers/composeConversationHelper.js';

import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  targetInbox: {
    type: Object,
    default: null,
  },
  selectedContact: {
    type: Object,
    default: null,
  },
  showInboxesDropdown: {
    type: Boolean,
    required: true,
  },
  contactableInboxesList: {
    type: Array,
    default: () => [],
  },
  managedCompanies: {
    type: Array,
    default: () => [],
  },
  selectedCompanyId: {
    type: Number,
    default: null,
  },
  hasErrors: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'updateInbox',
  'updateSelectedCompany',
  'toggleDropdown',
  'handleInboxAction',
]);

const { t } = useI18n();

const targetInboxLabel = computed(() => {
  return generateLabelForContactableInboxesList(props.targetInbox);
});

const companyMenuItems = computed(() =>
  props.managedCompanies.map(company => ({
    id: company.id,
    label: company.name,
    action: 'company',
    value: company.id,
  }))
);

const selectedCompanyLabel = computed(
  () =>
    props.managedCompanies.find(
      company => company.id === props.selectedCompanyId
    )?.name
);

const showCompanyDropdown = ref(false);

const handleCompanyAction = ({ value }) => {
  emit('updateSelectedCompany', value);
  showCompanyDropdown.value = false;
};

const clearSelectedCompany = () => {
  emit('updateSelectedCompany', null);
};

// The company-scoped channel list (companyEmailInboxesList) is built from
// ManagedCompany inboxes, independent of the contact. Only the legacy
// contact-history list (no managed companies configured) actually requires
// a contact to be selected first.
const isInboxButtonDisabled = computed(() => {
  if (props.selectedCompanyId) return false;
  return !props.selectedContact;
});
</script>

<template>
  <div
    class="flex items-center flex-1 w-full gap-3 px-4 py-3 overflow-y-visible"
  >
    <label class="mb-0.5 text-sm font-medium text-n-slate-11 whitespace-nowrap">
      {{ t('COMPOSE_NEW_CONVERSATION.FORM.INBOX_SELECTOR.LABEL') }}
    </label>
    <template v-if="!targetInbox && managedCompanies.length > 0">
      <div
        v-if="selectedCompanyId"
        class="flex items-center gap-1.5 rounded-md bg-n-alpha-2 truncate ltr:pl-3 rtl:pr-3 ltr:pr-1 rtl:pl-1 h-7 min-w-0"
      >
        <span class="text-sm truncate text-n-slate-12">
          {{ selectedCompanyLabel }}
        </span>
        <Button
          variant="ghost"
          icon="i-lucide-x"
          color="slate"
          size="xs"
          class="flex-shrink-0"
          @click="clearSelectedCompany"
        />
      </div>
      <div
        v-else
        v-on-click-outside="() => (showCompanyDropdown = false)"
        class="relative flex items-center h-7"
      >
        <Button
          :label="t('COMPOSE_NEW_CONVERSATION.FORM.COMPANY_SELECTOR.BUTTON')"
          variant="link"
          size="sm"
          color="slate"
          class="hover:!no-underline"
          @click="showCompanyDropdown = !showCompanyDropdown"
        />
        <DropdownMenu
          v-if="companyMenuItems.length > 0 && showCompanyDropdown"
          :menu-items="companyMenuItems"
          show-search
          :search-placeholder="
            t(
              'COMPOSE_NEW_CONVERSATION.FORM.COMPANY_SELECTOR.SEARCH_PLACEHOLDER'
            )
          "
          class="ltr:left-0 rtl:right-0 z-[100] top-8 overflow-y-auto max-h-56 w-fit max-w-sm dark:!outline-n-slate-5"
          @action="handleCompanyAction"
        />
      </div>
    </template>
    <div
      v-if="targetInbox"
      class="flex items-center gap-1.5 rounded-md bg-n-alpha-2 truncate ltr:pl-3 rtl:pr-3 ltr:pr-1 rtl:pl-1 h-7 min-w-0"
    >
      <span class="text-sm truncate text-n-slate-12">
        {{ targetInboxLabel }}
      </span>
      <Button
        variant="ghost"
        icon="i-lucide-x"
        color="slate"
        size="xs"
        class="flex-shrink-0"
        @click="emit('updateInbox', null)"
      />
    </div>
    <div
      v-else-if="!managedCompanies.length || selectedCompanyId"
      v-on-click-outside="() => emit('toggleDropdown', false)"
      class="relative flex items-center h-7"
    >
      <Button
        :label="t('COMPOSE_NEW_CONVERSATION.FORM.INBOX_SELECTOR.BUTTON')"
        variant="link"
        size="sm"
        :color="hasErrors ? 'ruby' : 'slate'"
        :disabled="isInboxButtonDisabled"
        class="hover:!no-underline"
        @click="emit('toggleDropdown', !showInboxesDropdown)"
      />
      <DropdownMenu
        v-if="contactableInboxesList?.length > 0 && showInboxesDropdown"
        :menu-items="contactableInboxesList"
        show-search
        :search-placeholder="
          t('COMPOSE_NEW_CONVERSATION.FORM.INBOX_SELECTOR.SEARCH_PLACEHOLDER')
        "
        class="ltr:left-0 rtl:right-0 z-[100] top-8 overflow-y-auto max-h-56 w-fit max-w-sm dark:!outline-n-slate-5"
        @action="emit('handleInboxAction', $event)"
      />
    </div>
  </div>
</template>
