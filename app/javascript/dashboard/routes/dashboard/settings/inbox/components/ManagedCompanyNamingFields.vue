<script>
import ManagedCompaniesAPI from 'dashboard/api/managedCompanies';
import UIButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    UIButton,
  },
  props: {
    managedCompanyId: {
      type: [Number, String, null],
      default: null,
    },
    inboxName: {
      type: String,
      default: '',
    },
    functionLabel: {
      type: String,
      default: '',
    },
    channelLabel: {
      type: String,
      default: '',
    },
    integrationSlot: {
      type: String,
      default: '',
    },
    hasSlotConflict: {
      type: Boolean,
      default: false,
    },
  },
  emits: [
    'update:managedCompanyId',
    'update:inboxName',
    'update:functionLabel',
    'update:hasSlotConflict',
  ],
  data() {
    return {
      managedCompanies: [],
      isManagedCompaniesLoading: false,
    };
  },
  computed: {
    selectedManagedCompany() {
      return this.managedCompanies.find(
        company => company.id === this.managedCompanyId
      );
    },
    inboxes() {
      return this.$store.getters['inboxes/getInboxes'] || [];
    },
    suggestedInboxName() {
      if (!this.selectedManagedCompany) {
        return '';
      }

      const parts = [
        this.selectedManagedCompany.name,
        this.channelLabel,
        this.functionLabel.trim(),
      ];

      return parts.filter(Boolean).join(' - ');
    },
    canApplySuggestedName() {
      return (
        !!this.suggestedInboxName &&
        this.suggestedInboxName !== this.inboxName?.trim()
      );
    },
    conflictingInbox() {
      if (!this.selectedManagedCompany || !this.integrationSlot) {
        return null;
      }

      return this.inboxes.find(inbox => {
        return (
          inbox.managed_company_id === this.selectedManagedCompany.id &&
          this.resolveInboxIntegrationSlot(inbox) === this.integrationSlot
        );
      });
    },
    conflictMessage() {
      if (!this.conflictingInbox) {
        return '';
      }

      return this.$t('INBOX_MGMT.ADD.MANAGED_COMPANY.SLOT_CONFLICT_MESSAGE', {
        company: this.selectedManagedCompany?.name,
        channel: this.channelLabel,
        inbox: this.conflictingInbox.name,
      });
    },
  },
  watch: {
    conflictingInbox: {
      immediate: true,
      handler(value) {
        const nextValue = !!value;
        if (nextValue === this.hasSlotConflict) {
          return;
        }

        this.$emit('update:hasSlotConflict', nextValue);
      },
    },
  },
  mounted() {
    this.fetchManagedCompanies();
    this.ensureInboxesLoaded();
  },
  methods: {
    async ensureInboxesLoaded() {
      if (this.inboxes.length) {
        return;
      }

      try {
        await this.$store.dispatch('inboxes/get');
      } catch (error) {
        // no-op
      }
    },
    async fetchManagedCompanies() {
      this.isManagedCompaniesLoading = true;
      try {
        const response = await ManagedCompaniesAPI.get();
        this.managedCompanies = response.data || [];
      } catch (error) {
        this.managedCompanies = [];
      } finally {
        this.isManagedCompaniesLoading = false;
      }
    },
    updateManagedCompanyId(event) {
      const value = event.target.value ? Number(event.target.value) : null;
      this.$emit('update:managedCompanyId', value);
    },
    updateFunctionLabel(event) {
      this.$emit('update:functionLabel', event.target.value);
    },
    applySuggestedName() {
      this.$emit('update:inboxName', this.suggestedInboxName);
    },
    resolveInboxIntegrationSlot(inbox) {
      if (!inbox) {
        return '';
      }

      if (
        inbox.channel_type === 'Channel::Instagram' ||
        (inbox.channel_type === 'Channel::FacebookPage' && inbox.instagram_id)
      ) {
        return 'instagram';
      }

      if (inbox.channel_type === 'Channel::FacebookPage') {
        return 'facebook';
      }

      if (
        inbox.channel_type === 'Channel::Whatsapp' ||
        (inbox.channel_type === 'Channel::TwilioSms' &&
          inbox.medium === 'whatsapp')
      ) {
        return 'whatsapp';
      }

      if (
        inbox.channel_type === 'Channel::Api' &&
        inbox.additional_attributes?.provider_type === 'linkedin'
      ) {
        return 'linkedin';
      }

      return '';
    },
  },
};
</script>

<template>
  <div class="grid gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-4">
    <div class="grid gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.MANAGED_COMPANY.TITLE') }}
      </span>
      <p class="mb-0 text-sm text-n-slate-11">
        {{ $t('INBOX_MGMT.ADD.MANAGED_COMPANY.SUBTITLE') }}
      </p>
    </div>

    <label>
      {{ $t('INBOX_MGMT.ADD.MANAGED_COMPANY.COMPANY_LABEL') }}
      <select
        :value="managedCompanyId"
        class="mb-0"
        @change="updateManagedCompanyId"
      >
        <option :value="null">
          {{ $t('INBOX_MGMT.ADD.MANAGED_COMPANY.COMPANY_PLACEHOLDER') }}
        </option>
        <option
          v-for="managedCompany in managedCompanies"
          :key="managedCompany.id"
          :value="managedCompany.id"
        >
          {{ `${managedCompany.name} - ${managedCompany.authorized_domain}` }}
        </option>
      </select>
    </label>

    <p v-if="isManagedCompaniesLoading" class="mb-0 text-sm text-n-slate-11">
      {{ $t('INBOX_MGMT.ADD.MANAGED_COMPANY.LOADING') }}
    </p>

    <div
      v-if="conflictingInbox"
      class="grid gap-1 rounded-xl border border-n-amber-8 bg-n-amber-3 px-3 py-2"
    >
      <span class="text-sm font-medium text-n-amber-11">
        {{ $t('INBOX_MGMT.ADD.MANAGED_COMPANY.SLOT_CONFLICT_TITLE') }}
      </span>
      <p class="mb-0 text-sm text-n-slate-12">
        {{ conflictMessage }}
      </p>
    </div>

    <label>
      {{ $t('INBOX_MGMT.ADD.MANAGED_COMPANY.FUNCTION_LABEL') }}
      <input
        :value="functionLabel"
        type="text"
        :placeholder="$t('INBOX_MGMT.ADD.MANAGED_COMPANY.FUNCTION_PLACEHOLDER')"
        @input="updateFunctionLabel"
      />
    </label>

    <div v-if="selectedManagedCompany" class="grid gap-1">
      <span class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
        {{ $t('INBOX_MGMT.ADD.MANAGED_COMPANY.PREVIEW_LABEL') }}
      </span>
      <span class="text-sm text-n-slate-12">
        {{ suggestedInboxName }}
      </span>
    </div>

    <div class="flex justify-start">
      <UIButton
        slate
        sm
        :disabled="!canApplySuggestedName"
        :label="$t('INBOX_MGMT.ADD.MANAGED_COMPANY.APPLY_SUGGESTION')"
        @click="applySuggestedName"
      />
    </div>
  </div>
</template>
