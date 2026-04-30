<script>
import { reactive } from 'vue';
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';

import FormInput from 'v3/components/Form/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import validations from './helpers/validations';
import ManagedCompaniesAPI from 'dashboard/api/managedCompanies';

const buildAssignment = assignment => {
  const {
    managed_company_id: managedCompanyId = '',
    inbox_ids: inboxIds = [],
  } = assignment || {};

  return {
    managedCompanyId: managedCompanyId || '',
    inboxIds,
  };
};

export default {
  components: {
    NextButton,
    FormInput,
  },
  props: {
    onSubmit: {
      type: Function,
      default: () => {},
    },
    submitInProgress: {
      type: Boolean,
      default: false,
    },
    formData: {
      type: Object,
      default: () => {},
    },
    submitButtonText: {
      type: String,
      default: '',
    },
  },
  setup(props) {
    const formData = props.formData || {};
    const {
      description = '',
      name: title = '',
      allow_auto_assign: allowAutoAssign = true,
      managed_company_assignments: managedCompanyAssignments = [],
    } = formData;

    const state = reactive({
      description,
      title,
      allowAutoAssign,
      managedCompanyAssignments:
        managedCompanyAssignments.length > 0
          ? managedCompanyAssignments.map(buildAssignment)
          : [],
    });

    const rules = validations;
    const v$ = useVuelidate(rules, state);
    return { state, v$ };
  },
  data() {
    return {
      managedCompanies: [],
      isManagedCompaniesLoading: false,
    };
  },
  computed: {
    ...mapGetters({
      inboxes: 'inboxes/getInboxes',
    }),
    inboxOptions() {
      return this.inboxes || [];
    },
    hasManagedCompanies() {
      return this.managedCompanies.length > 0;
    },
  },
  mounted() {
    this.fetchManagedCompanies();
    if (!this.inboxOptions.length) {
      this.$store.dispatch('inboxes/get');
    }
  },
  methods: {
    async fetchManagedCompanies() {
      this.isManagedCompaniesLoading = true;
      try {
        const response = await ManagedCompaniesAPI.get();
        this.managedCompanies = response.data || [];
      } finally {
        this.isManagedCompaniesLoading = false;
      }
    },
    addManagedCompanyAssignment() {
      this.state.managedCompanyAssignments.push(buildAssignment());
    },
    removeManagedCompanyAssignment(index) {
      this.state.managedCompanyAssignments.splice(index, 1);
    },
    onManagedCompanyChange(index) {
      const assignment = this.state.managedCompanyAssignments[index];
      const validInboxIds = this.inboxesForManagedCompany(
        assignment.managedCompanyId
      ).map(inbox => inbox.id);

      assignment.inboxIds = assignment.inboxIds.filter(inboxId =>
        validInboxIds.includes(inboxId)
      );
    },
    availableManagedCompanies(currentManagedCompanyId) {
      const selectedManagedCompanyIds = this.state.managedCompanyAssignments
        .map(({ managedCompanyId }) => managedCompanyId)
        .filter(Boolean);

      return this.managedCompanies.filter(({ id }) => {
        return (
          id === currentManagedCompanyId ||
          !selectedManagedCompanyIds.includes(id)
        );
      });
    },
    inboxesForManagedCompany(managedCompanyId) {
      return this.inboxOptions.filter(({ managed_company_id: companyId }) => {
        return companyId === managedCompanyId;
      });
    },
    normalizedManagedCompanyAssignments() {
      return this.state.managedCompanyAssignments
        .filter(({ managedCompanyId }) => Boolean(managedCompanyId))
        .map(({ managedCompanyId, inboxIds }) => ({
          managed_company_id: managedCompanyId,
          inbox_ids: inboxIds,
        }));
    },
    handleSubmit() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      this.onSubmit({
        description: this.state.description,
        name: this.state.title,
        allow_auto_assign: this.state.allowAutoAssign,
        managed_company_assignments: this.normalizedManagedCompanyAssignments(),
      });
    },
  },
};
</script>

<template>
  <div class="flex-shrink-0 w-full">
    <form class="mx-0 grid gap-4" @submit.prevent="handleSubmit">
      <FormInput
        v-model="state.title"
        name="title"
        spacing="compact"
        :label="$t('TEAMS_SETTINGS.FORM.NAME.LABEL')"
        :placeholder="$t('TEAMS_SETTINGS.FORM.NAME.PLACEHOLDER')"
        :has-error="v$.title.$error"
        :error-message="v$.title.$error ? v$.title.$errors[0].$message : ''"
        @blur="v$.title.$touch"
      />
      <FormInput
        v-model="state.description"
        name="description"
        spacing="compact"
        :label="$t('TEAMS_SETTINGS.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('TEAMS_SETTINGS.FORM.DESCRIPTION.PLACEHOLDER')"
        :has-error="v$.description.$error"
        :error-message="
          v$.description.$error ? v$.description.$errors[0].$message : ''
        "
        @blur="v$.description.$touch"
      />
      <div class="w-full flex items-center gap-2">
        <input v-model="state.allowAutoAssign" type="checkbox" :value="true" />
        <label for="conversation_creation">
          {{ $t('TEAMS_SETTINGS.FORM.AUTO_ASSIGN.LABEL') }}
        </label>
      </div>
      <div class="grid gap-3 rounded-lg border border-n-weak p-4">
        <div class="flex items-start justify-between gap-3">
          <div>
            <p class="mb-1 text-sm font-medium text-n-slate-12">
              {{ $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.TITLE') }}
            </p>
            <p class="mb-0 text-sm text-n-slate-11">
              {{ $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.DESCRIPTION') }}
            </p>
          </div>
          <NextButton
            type="button"
            size="sm"
            slate
            :label="$t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.ADD')"
            @click="addManagedCompanyAssignment"
          />
        </div>

        <p
          v-if="isManagedCompaniesLoading"
          class="mb-0 text-sm text-n-slate-11"
        >
          {{ $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.LOADING') }}
        </p>
        <p
          v-else-if="!hasManagedCompanies"
          class="mb-0 text-sm text-n-slate-11"
        >
          {{ $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.EMPTY') }}
        </p>

        <div
          v-for="(assignment, index) in state.managedCompanyAssignments"
          :key="`${assignment.managedCompanyId || 'new'}-${index}`"
          class="grid gap-3 rounded-lg border border-n-weak bg-n-alpha-1 p-3"
        >
          <div class="grid gap-2 md:grid-cols-[minmax(0,1fr)_auto]">
            <label class="grid gap-2 text-sm font-medium text-n-slate-12">
              {{ $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.COMPANY_LABEL') }}
              <select
                v-model="assignment.managedCompanyId"
                class="h-10 rounded-lg border border-n-weak bg-n-background px-3 text-sm text-n-slate-12"
                @change="onManagedCompanyChange(index)"
              >
                <option value="">
                  {{
                    $t(
                      'TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.COMPANY_PLACEHOLDER'
                    )
                  }}
                </option>
                <option
                  v-for="managedCompany in availableManagedCompanies(
                    assignment.managedCompanyId
                  )"
                  :key="managedCompany.id"
                  :value="managedCompany.id"
                >
                  {{ managedCompany.name }} ({{
                    managedCompany.authorized_domain
                  }})
                </option>
              </select>
            </label>

            <div class="flex items-end">
              <NextButton
                type="button"
                size="sm"
                slate
                :label="$t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.REMOVE')"
                @click="removeManagedCompanyAssignment(index)"
              />
            </div>
          </div>

          <label class="grid gap-2 text-sm font-medium text-n-slate-12">
            {{ $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.INBOXES_LABEL') }}
            <select
              v-model="assignment.inboxIds"
              multiple
              :disabled="!assignment.managedCompanyId"
              class="min-h-32 rounded-lg border border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12"
            >
              <option
                v-for="inbox in inboxesForManagedCompany(
                  assignment.managedCompanyId
                )"
                :key="inbox.id"
                :value="inbox.id"
              >
                {{ inbox.name }}
              </option>
            </select>
            <span class="text-xs font-normal text-n-slate-11">
              {{
                $t('TEAMS_SETTINGS.FORM.MANAGED_COMPANIES.INBOXES_PLACEHOLDER')
              }}
            </span>
          </label>
        </div>
      </div>
      <div class="flex flex-row justify-end gap-2 py-2 px-0 w-full">
        <div class="w-full">
          <NextButton
            type="submit"
            :label="submitButtonText"
            :disabled="v$.title.$invalid || submitInProgress"
            :is-loading="submitInProgress"
          />
        </div>
      </div>
    </form>
  </div>
</template>
