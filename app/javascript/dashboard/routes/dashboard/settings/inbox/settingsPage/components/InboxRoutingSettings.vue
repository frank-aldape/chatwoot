<script>
import { useVuelidate } from '@vuelidate/core';
import { minValue } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { useConfig } from 'dashboard/composables/useConfig';
import SettingsSection from '../../../../../../components/SettingsSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ManagedCompaniesAPI from 'dashboard/api/managedCompanies';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

export default {
  components: {
    SettingsSection,
    NextButton,
  },
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  setup() {
    const { isEnterprise } = useConfig();

    return { v$: useVuelidate(), isEnterprise };
  },
  data() {
    return {
      managedCompanies: [],
      selectedManagedCompanyId: null,
      isManagedCompanyUpdating: false,
      enableAutoAssignment: false,
      maxAssignmentLimit: null,
    };
  },
  computed: {
    selectedManagedCompany: {
      get() {
        return (
          this.managedCompanies.find(
            c => c.id === this.selectedManagedCompanyId
          ) || null
        );
      },
      set(value) {
        this.selectedManagedCompanyId = value?.id || null;
      },
    },
    maxAssignmentLimitErrors() {
      if (this.v$.maxAssignmentLimit.$error) {
        return this.$t(
          'INBOX_MGMT.AUTO_ASSIGNMENT.MAX_ASSIGNMENT_LIMIT_RANGE_ERROR'
        );
      }
      return '';
    },
  },
  watch: {
    inbox() {
      this.setDefaults();
    },
  },
  mounted() {
    this.fetchManagedCompanies();
    this.setDefaults();
  },
  methods: {
    setDefaults() {
      this.enableAutoAssignment = this.inbox.enable_auto_assignment;
      this.maxAssignmentLimit =
        this.inbox?.auto_assignment_config?.max_assignment_limit || null;
      this.selectedManagedCompanyId = this.inbox.managed_company_id || null;
    },
    async fetchManagedCompanies() {
      try {
        const response = await ManagedCompaniesAPI.get();
        this.managedCompanies = response.data || [];
      } catch (error) {
        this.managedCompanies = [];
      }
    },
    handleEnableAutoAssignment() {
      this.updateInbox();
    },
    async updateManagedCompany() {
      this.isManagedCompanyUpdating = true;
      try {
        await this.$store.dispatch('inboxes/updateInbox', {
          id: this.inbox.id,
          formData: false,
          managed_company_id: this.selectedManagedCompanyId,
        });
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(
          parseAPIErrorResponse(error) ||
            this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE')
        );
      }
      this.isManagedCompanyUpdating = false;
    },
    companyLabel({ name, authorized_domain: domain }) {
      return domain ? `${name} (${domain})` : name;
    },
    async updateInbox() {
      try {
        await this.$store.dispatch('inboxes/updateInbox', {
          id: this.inbox.id,
          formData: false,
          enable_auto_assignment: this.enableAutoAssignment,
          auto_assignment_config: {
            max_assignment_limit: this.maxAssignmentLimit,
          },
        });
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      }
    },
  },
  validations: {
    maxAssignmentLimit: {
      minValue: minValue(1),
    },
  },
};
</script>

<template>
  <div>
    <SettingsSection
      :title="$t('INBOX_MGMT.SETTINGS_POPUP.MANAGED_COMPANY')"
      :sub-title="$t('INBOX_MGMT.SETTINGS_POPUP.MANAGED_COMPANY_SUB_TEXT')"
    >
      <multiselect
        v-model="selectedManagedCompany"
        :options="managedCompanies"
        track-by="id"
        :custom-label="companyLabel"
        :placeholder="
          $t('INBOX_MGMT.SETTINGS_POPUP.MANAGED_COMPANY_PLACEHOLDER')
        "
        :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
        :deselect-label="$t('FORMS.MULTISELECT.ENTER_TO_REMOVE')"
        allow-empty
      />

      <NextButton
        :label="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
        :is-loading="isManagedCompanyUpdating"
        @click="updateManagedCompany"
      />
    </SettingsSection>

    <SettingsSection
      :title="$t('INBOX_MGMT.SETTINGS_POPUP.AGENT_ASSIGNMENT')"
      :sub-title="$t('INBOX_MGMT.SETTINGS_POPUP.AGENT_ASSIGNMENT_SUB_TEXT')"
    >
      <label class="w-3/4 settings-item">
        <div class="flex items-center gap-2">
          <input
            id="enableAutoAssignment"
            v-model="enableAutoAssignment"
            type="checkbox"
            @change="handleEnableAutoAssignment"
          />
          <label for="enableAutoAssignment">
            {{ $t('INBOX_MGMT.SETTINGS_POPUP.AUTO_ASSIGNMENT') }}
          </label>
        </div>

        <p class="pb-1 text-sm not-italic text-n-slate-11">
          {{ $t('INBOX_MGMT.SETTINGS_POPUP.AUTO_ASSIGNMENT_SUB_TEXT') }}
        </p>
      </label>

      <div v-if="enableAutoAssignment && isEnterprise" class="py-3">
        <woot-input
          v-model="maxAssignmentLimit"
          type="number"
          :class="{ error: v$.maxAssignmentLimit.$error }"
          :error="maxAssignmentLimitErrors"
          :label="$t('INBOX_MGMT.AUTO_ASSIGNMENT.MAX_ASSIGNMENT_LIMIT')"
          @blur="v$.maxAssignmentLimit.$touch"
        />

        <p class="pb-1 text-sm not-italic text-n-slate-11">
          {{ $t('INBOX_MGMT.AUTO_ASSIGNMENT.MAX_ASSIGNMENT_LIMIT_SUB_TEXT') }}
        </p>

        <NextButton
          :label="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
          :disabled="v$.maxAssignmentLimit.$invalid"
          @click="updateInbox"
        />
      </div>
    </SettingsSection>
  </div>
</template>
